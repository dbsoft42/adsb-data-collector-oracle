import asyncio
import aiohttp
import cx_Oracle
from datetime import datetime, time
from dateutil.relativedelta import relativedelta
from copy import deepcopy
from config import config

async def process_dataset(cursor, dataset):
    '''This calls the PL/SQL procedure and is called from the main/driver function as an async task'''
    cursor.callproc('pkg_adsb_loader.load_data', [str(dataset)])

async def cleanup(cursor):
    '''
    This procedure cleans up rows from the JSON_STAGE table that are older than the
    max age mentioned in the config dict
    '''
    while True:
        cursor.callproc('pkg_adsb_loader.stage_cleanup', [config['stage_rows_max_age']])
        await asyncio.sleep(config['cleanup_run_interval'])


async def main():
    '''The driver function - will get the JSON from the URL and call process_dataset'''
    # Initialize DB connection
    ora = cx_Oracle.connect(
                            config['db']['username'],
                            config['db']['password'],
                            config['db']['host'] + '/' + config['db']['service_name']
                            )
    cursor = ora.cursor()

    # Setting params in the PL/SQL package
    cursor.callproc('pkg_adsb_loader.set_params', [config['orphan_status_update_max_age']])

    # Create a separate task for the cleanup function
    asyncio.create_task(cleanup(cursor))

    async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=config['http_timeout'])) as http_session:
        while True:
            try:
                async with http_session.get(config['dump1090_url']) as response:
                    dataset = await response.json()
            except Exception as exc:
                print(f'EXCEPTION!')
                print(exc)
                await asyncio.sleep(config['source_poll_interval'])
                continue
            asyncio.create_task(process_dataset(cursor, dataset))
            await asyncio.sleep(config['source_poll_interval'])



if __name__ == '__main__':
    asyncio.run(main())
