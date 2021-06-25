import cx_Oracle
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from random import randrange
from time import sleep
from config import config

# Planespotters credentials
planespotters_username = 'Enter your username here'
planespotters_password = 'Your password here'
# Selenium Chrome webdriver path - include the file name
chrome_driver_path = r'C:\chromedriver_win32\chromedriver.exe'
# Oracle instant client path - not needed if you can connect without it
ora_instant_client_path = r'C:\instantclient_19_11'
# These many records will be fetched, updated and committed per batch
batch_size = 5
max_request_spacing = 5 # secs

# Initialize DB connection
cx_Oracle.init_oracle_client(lib_dir=ora_instant_client_path)
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

# Login
driver.get('https://www.planespotters.net/user/login')
if driver.current_url != 'https://www.planespotters.net/':
    driver.find_element(By.NAME, 'username').send_keys(planespotters_username)
    driver.find_element(By.NAME, 'password').send_keys(planespotters_password)
    driver.find_element(By.CLASS_NAME, 'btn-block').click()
if driver.current_url != 'https://www.planespotters.net/':
    print("The login didn't work")
    exit()

sql = f"SELECT hex, comments FROM aircraft WHERE registration IS NULL \
        AND nvl(comments, ' ') NOT LIKE '%planespotters NF%' AND rownum <= {batch_size}"
upd_sql = "UPDATE aircraft \
            SET registration = nullif(:ac_registration, 'N/A'), \
            model = nullif(:ac_model, 'N/A'), \
            operator = nullif(:ac_operator, 'N/A'), \
            comments = :ac_comments \
            WHERE hex = :ac_hex"
while True:
    for hex, comments in cursor_sql.execute(sql):
        # Fetch details from web
        url = f'https://www.planespotters.net/hex/{hex.upper()}'
        print(f'Trying URL: {url}')
        driver.get(url)
        # We put in a random sleep after each request to avoid flooding
        # But instead of doing this at the end, we do it here to utilize the time for page loading
        sleep(randrange(1, max_request_spacing+1))
        #sleep(10)
        # Eliminate any residual data from the previous iteration
        ac_registration = ac_model = ac_operator = ac_comments = ''
        # Get the data elements from the page
        for e in driver.find_elements(By.CLASS_NAME, 'dt-td-nowrap'):
            try:
                if e.find_element(By.TAG_NAME, 'a').get_attribute('title') == 'View detailed Information about this airframe':
                    ac_registration = e.text
                    break
            except Exception:
                continue
        for e in driver.find_elements(By.CLASS_NAME, 'dt-td-min150'):
            try:
                if '/production-list/' in e.find_element(By.TAG_NAME, 'a').get_attribute('href'):
                    ac_model = e.text
                    break
            except Exception:
                continue
        for e in driver.find_elements(By.CLASS_NAME, 'dt-td-min150'):
            try:
                if '/airline/' in e.find_element(By.TAG_NAME, 'a').get_attribute('href'):
                    ac_operator = e.text
                    break
            except Exception:
                continue
        print(f"DATA: {ac_model}      {ac_registration}      {ac_operator}")
        if ac_registration == None or ac_registration == '':
            if comments != None:
                ac_comments = comments + '; planespotters NF'
            else:
                ac_comments = 'planespotters NF'
        else:
            ac_comments = comments
        # Update record
        cursor_upd.execute(upd_sql, [ac_registration, ac_model, ac_operator, ac_comments, hex])
    # End of batch
    if cursor_sql.rowcount > 0:
        print('Commit point reached')
        ora.commit()
    else:
        break

driver.close()
ora.close()
