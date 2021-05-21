# Make a copy of this file as config.py and update the required values below.
# The MongoDB connection details and the dump1090 URL are the ones you really need to look at.
# The rest can be left at the defaults to start with.

config = {} # Ignore this line

# Oracle database connection details
config['db'] = {
                'host':         'localhost',
                'service_name': 'pdb1',
                'username':     'adsb',
                'password':     '******'
                } 

# Dump1090 URL for the aircraft.json file
config['dump1090_url'] = 'http://192.168.1.115/dump1090/data/aircraft.json'

# Once a flight ID is received for the first time,
# status records already inserted to the DB can be updated with the flight ID.
# Records only up to these many seconds will be updated.
config['orphan_status_update_max_age'] = 600 # seconds

# The source (dump1090 JSON URL) will be checked every:
# This affects how often the script checks dump1090 for updated status
# Increasing this interval is a way to reduce amount of data going into the DB.
config['source_poll_interval'] = 10 # seconds

# The timeout for the HTTP request to get the JSON file from dump1090
# If a response if not received within this period, the request will be aborted.
# This will not fail the script and it will try the next request after the source_poll_interval.
# If your dump1090 is running locally, a short timeout is fine.
# If your source_poll_interval is short, better to keep the timeout short.
config['http_timeout'] = 5 # seconds

# A stage table hold the raw JSON data from dump1090 along with a few other fields.
# This acts as the raw data which the PL/SQL package code processes and laods into the final tables.
# Once loaded, this raw data is no longer needed except maybe for you analysis purposes,
# such as to see how long each load has taken.
# A cleanup function periodically trims this table to keep it from growing too much.
# The following 2 options control how often the cleanup runs
config['cleanup_run_interval'] = 3600 # seconds
# and how old the messages can be before they are removed.
config['stage_rows_max_age'] = 172800 # seconds
