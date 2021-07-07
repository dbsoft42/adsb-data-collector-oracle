import asyncio
import aiohttp
import cx_Oracle
from datetime import datetime, time
from dateutil.relativedelta import relativedelta
import logging, logging.handlers
from os.path import join
from config import config

def log_setup():
    logger = logging.getLogger(__name__)
    logger.setLevel(config['logging']['log_level'])
    if config['logging']['enabled']:
        log_file = join(config['logging']['log_dir'], config['logging']['log_file_name'])
        logging_file_handler = logging.handlers.TimedRotatingFileHandler(
                                                        filename=log_file,
                                                        when='midnight',
                                                        backupCount=config['logging']['log_file_hist_count']
                                                        )
        logging_file_handler.setLevel(config['logging']['log_level'])
        logging_file_handler.setFormatter(logging.Formatter(config['logging']['log_format']))
        logger.addHandler(logging_file_handler)
    if config['pushover']['enabled']:
        from LogPushoverHandler import LogPushoverHandler
        pushover_handler = LogPushoverHandler(
                                                token=config['pushover']['token'],
                                                user=config['pushover']['user']
                                                )
        pushover_handler.setLevel(config['pushover']['log_level'])
        pushover_handler.setFormatter(logging.Formatter(config['pushover']['log_format']))
        logger.addHandler(pushover_handler)
    return logger

async def process_dataset(dataset):
    '''This calls the PL/SQL procedure and is called from the main/driver function as an async task'''
    res = cursor.var(str)
    try:
        cursor.callproc('pkg_adsb_loader.load_data', [str(dataset), res])
        logger.info(f'DB operation results: {res.getvalue()}')
        max_consecutive_db_errors = config['max_consecutive_db_errors']
    except Exception as exc:
        logger.info(f'DB operation results: {res.getvalue()}')
        logger.exception('Something went wrong with the Oracle procedure call')
        max_consecutive_db_errors -= 1
        raise exc

async def cleanup():
    '''
    This procedure cleans up rows from the JSON_STAGE table that are older than the
    max age mentioned in the config dict
    '''
    res = cursor.var(str)
    while True:
        try:
            logger.info('Cleanup: starting')
            cursor.callproc('pkg_adsb_loader.stage_cleanup', [config['stage_rows_max_age'], res])
            logger.info(f'Cleanup: {res.getvalue()}')
            logger.info('Cleanup: complete')
            max_consecutive_db_errors = config['max_consecutive_db_errors']
            await asyncio.sleep(config['cleanup_run_interval'])
        except Exception as exc:
            logger.exception('Cleanup: Something went wrong with the Oracle procedure call')
            max_consecutive_db_errors -= 1
            raise exc



async def main():
    '''The driver function - will get the JSON from the URL and call process_dataset'''
    global max_consecutive_db_errors, cursor, logger
    try:
        max_consecutive_http_errors = config['max_consecutive_http_errors']
        max_consecutive_db_errors = config['max_consecutive_db_errors']

        # Set up logging
        logger = log_setup()
        logger.info('Program starting')

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
        asyncio.create_task(cleanup())

        async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=config['http_timeout'])) as http_session:
            while True:
                try:
                    async with http_session.get(config['dump1090_url']) as response:
                        dataset = await response.json()
                except Exception as exc:
                    logger.debug(f"HTTP error, remaining allowance: {max_consecutive_http_errors}")
                    logger.exception('Something went wrong while fetching data from dump1090')
                    if max_consecutive_http_errors == 0:
                        logger.critical('Maximum consecutive errors exceeded')
                        raise exc
                    max_consecutive_http_errors -= 1
                    await asyncio.sleep(config['source_poll_interval'])
                    continue
                logger.debug(f'Dataset received from dump1090:\n{dataset}')
                logger.info(f"Got {len(dataset['aircraft'])} aircraft detail messages from dump1090")
                loader_task = asyncio.create_task(process_dataset(dataset))
                await asyncio.sleep(config['source_poll_interval'])
                if max_consecutive_db_errors == 0:
                    raise cx_Oracle.Error
    except Exception as exc:
        logger.exception('Something went wrong')
        logger.critical('This is a fatal error. Exiting.')


if __name__ == '__main__':
    asyncio.run(main())
