import cx_Oracle
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from random import randrange
from time import sleep
from config import config

# Selenium Chrome webdriver path - include the file name
chrome_driver_path = r'C:\chromedriver_win32\chromedriver.exe'
# Oracle instant client path - not needed if you can connect without it
#ora_instant_client_path = r'C:\instantclient_19_11'
# These many records will be fetched, updated and committed per batch
batch_size = 5
max_request_spacing = 5 # secs

# Initialize DB connection
# Uncomment the line below if you need to use the Oracle Instant Client
#cx_Oracle.init_oracle_client(lib_dir=ora_instant_client_path)
ora = cx_Oracle.connect(
                        config['db']['username'],
                        config['db']['password'],
                        config['db']['host'] + '/' + config['db']['service_name']
                        )
cursor_sql = ora.cursor()
cursor_upd = ora.cursor()

#Initialize Selenium Chrome webdriver
chrome_options = Options()
chrome_options.add_argument('--headless')
chrome_options.add_argument('--log-level=3')
driver = webdriver.Chrome(
                                executable_path=chrome_driver_path,
                                options=chrome_options
                            )

sql = f"SELECT hex, comments FROM aircraft WHERE registration IS NULL \
        AND nvl(comments, ' ') NOT LIKE '%opensky NF%' AND rownum <= {batch_size}"
upd_sql = "UPDATE aircraft \
            SET registration = nullif(:ac_registration, 'N/A'), \
            model = nullif(:ac_model, 'N/A'), \
            type = nullif(:ac_type, 'N/A'), \
            operator = nullif(:ac_operator, 'N/A'), \
            comments = :ac_comments \
            WHERE hex = :ac_hex"
while True:
    for hex, comments in cursor_sql.execute(sql):
        # Fetch details from web
        url = f'https://opensky-network.org/aircraft-profile?icao24={hex}'
        print(f'Trying URL: {url}')
        driver.get(url)
        # We put in a random sleep after each request to avoid flooding
        # But instead of doing this at the end, we do it here to utilize the time for page loading
        sleep(randrange(1, max_request_spacing+1))
        #sleep(10)
        # Get the data elements from the page
        ac_type = driver.find_element_by_id('ap_typecode').text
        ac_manufacturer = driver.find_element_by_id('ap_manufacturerName').text
        ac_model = driver.find_element_by_id('ap_model').text
        ac_registration = driver.find_element_by_id('ap_registration').text
        ac_owner = driver.find_element_by_id('ap_owner').text
        ac_operator = driver.find_element_by_id('ap_operator').text
        # Combine manufacturer and model if model does not have the manufacturer name
        if ac_manufacturer.lower() not in ac_model.lower():
            ac_model = ac_manufacturer + ' ' + ac_model
        # Combine owner and operator
        if ac_operator == 'N/A':
            ac_operator = ac_owner
        print(f"DATA: {ac_type}      {ac_model}      {ac_registration}      {ac_operator}")
        if ac_registration == None or ac_registration == '' or ac_registration == 'N/A':
            if comments != None:
                ac_comments = comments + '; opensky NF'
            else:
                ac_comments = 'opensky NF'
        else:
            ac_comments = comments
        # Update record
        cursor_upd.execute(upd_sql, [ac_registration, ac_model, ac_type, ac_operator, ac_comments, hex])
    # End of batch
    if cursor_sql.rowcount > 0:
        print('Commit point reached')
        ora.commit()
    else:
        break

driver.close()
ora.close()
