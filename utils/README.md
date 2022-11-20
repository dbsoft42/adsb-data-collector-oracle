# Utilities
This folder contains utility scripts for various purposes. Please see details on each below and how to use them.

## Planespotters.net scraper to populate aircraft details.
This script fetches aircraft details from planespotters.net and populates your **aircraft** table.

#### Requirements
* This script uses the Selenium webdriver to simulate the browser activity. 
  *  You need to have Chrome installed on the system running this script
  *  Download the [Chrome webdriver](https://chromedriver.chromium.org/downloads) for your platform and place in a folder of your choice.
  *  Install the Python Selenium library.
     ```
     pip3 install selenuim
     ```
* Depending on where you're running the script, you may need to download the Oracle Instant Client. This may not be needed if the system already has Oracle database software installed. If not, please download the instant client for your platform from [here](https://www.oracle.com/database/technologies/instant-client/downloads.html).
* You need to register with planespotters.net and create an account if you don't already have one. *You need to be registered with planespotters.net as not logged-in users can only do a few queries.*

#### To use:
* Ensure you have the **aircraft** table structure according to the latest `db/tables.sql` which includes the additional columns for aircraft information like registration, etc.
* Copy the script `scraper_planespotters.py` from the `utils` folder to the parent folder.
* Edit the script and enter your planespotters.net credentials in the marked section (lines 10 and 11).
* Edit the script and modify the **chrome_driver_path** directory path to the location where you placed the Chrome webdriver.
* If you need to use the Oracle Instant Client, uncomment line 15 and put in your path there. Also uncomment line 22. To find out if you need it, you may try running it first. 
* Run the script as `python3 scraper_planespotters.py`. If you have a lot of aircraft in your table that are to be updated, it may take a while to finish.

#### The following parameters can be tuned in the script.
* **batch_size**: These many records will be fetched from the database and committed per batch. A bigger size means more records will be retrieved from the DB in a single query, but more records will remain uncommitted until the batch completes.
* **max_request_spacing**: A random number of seconds between 1 and max_request_spacing is used to space each request to planespotters.net. This is to prevent flooding their system with too many requests at once and make the requests have a more natural flow.


## Opensky network scraper to populate aircraft details.
This script fetches aircraft details from opensky-network.org and populates your **aircraft** table.

#### Requirements
* This script uses the Selenium webdriver to simulate the browser activity. 
  *  You need to have Chrome installed on the system running this script
  *  Download the [Chrome webdriver](https://chromedriver.chromium.org/downloads) for your platform and place in a folder of your choice.
  *  Install the Python Selenium library.
     ```
     pip3 install selenuim
     ```
* Depending on where you're running the script, you may need to download the Oracle Instant Client. This may not be needed if the system already has Oracle database software installed. If not, please download the instant client for your platform from [here](https://www.oracle.com/database/technologies/instant-client/downloads.html).

#### To use:
* Ensure you have the **aircraft** table structure according to the latest `db/tables.sql` which includes the additional columns for aircraft information like registration, etc.
* Copy the script `scraper_opensky.py` from the `utils` folder to the parent folder.
* Edit the script and modify the **chrome_driver_path** directory path to the location where you placed the Chrome webdriver.
* If you need to use the Oracle Instant Client, uncomment line 11 and put in your path there. Also uncomment line 18. To find out if you need it, you may try running it first. 
* Run the script as `python3 scraper_opensky.py`. If you have a lot of aircraft in your table that are to be updated, it may take a while to finish.

