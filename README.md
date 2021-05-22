adsb-data-collector-oracle
======
## An semi-asynchronous Python script to continuously feed ADS-B data from dump1090 to an Oracle database

### What does this do?
This is mainly a single script that runs continuously and collects [ADS-B](https://en.wikipedia.org/wiki/Automatic_Dependent_Surveillance%E2%80%93Broadcast "What is ADS-B?") data from your dump1090 instance and stores it in Oracle database tables.

* Works with *[dump1090-fa](https://github.com/adsbxchange/dump1090-fa)* and should work with *[dump1090-mutability](https://github.com/adsbxchange/dump1090-mutability)* too, but it's not tested. Please drop me a line if it works for you.
* Written in *Python* and Oracle *PL/SQL*.
* Most of the database operations to load a set of data received from dump1090 is triggered by a single PL/SQL procedure call. Although the cx_Oracle libary does not support asynchronous operations, Python asyncio coroutines are used to reduce delays as far as possible from the database operations.

### Requirements
* A configured and running **dump1090** instance (see links above). This can be yours or a friend's but you should be able to access it from wherever you intend to run this script, if the script is not running on the same machine as dump1090.
* An Oracle database - any recent version should be fine. You should have full read/write access to at least one schema where the ADS-B tables will be stored.
* Python 3.7+
* Python libraries
  * aiohttp
  * cx_Oracle
  * Python-dateutil

### Installation and setup
Download the files to the directory where you want to run it. I recommend having a dedicated directory/folder for this.
```
git clone https://github.com/dbsoft42/adsb-data-collector-oracle.git
```
Install the required Python libraries.
```
pip3 install aiohttp cx_Oracle python-dateutil
```
The *db* directory/folder has 2 scripts.
  * tables.sql - Contains statements to create the required tables and view.
  * pkg_adsb_loader.sql - Contains the definition for the PL/SQL package that handles the data loading logic and operations.
Connect to your preferred Oracle database client and execute these 2 scripts.

Copy the *config_template.py* file to *config.py*.
```
cp config_template.py config.py
```
Edit *config.py* in your favourite text editor and change the following parameters.
* `config['db']` - Set the various database connection parameters under this. They are pretty self-explanatory. If you don't manage your own database or don't know what these should be, you can get them from your database administrator.
* `dump1090_url` - This is the dump1090 URL which serves the *aircraft.json* file. Typically this will be in the form of `http://hostname/dump1090/data/aircraft.json` where *hostname* is the host name or IP address of the machine where *dump1090* is running. If you will be running this script on the same machine where dump1090 is running, you can leave it as *localhost*.

The file has more parameters for fine-tuning various operations. You can leave these as the defaults or tune them if you need. The file has comments describing in more detail what each parameter is used for.

Do a quick test run.
```
python3 adsb-data-collector.py
```
Let it run for a few seconds (or longer if you wish). If all goes well, you should not see any output on the terminal. Check your Oracle database to see if data is being loaded on to the **aircraft**, **flights** and **status** tables. If yes, you are good to go! Stop the running script with CTRL+C.

To run it for the long term, I suggest running in in the background with nohup as shown below, but you can choose your own method. The script will basically run indefinitely once started.
```
nohup adsb-data-collector.py &
```
