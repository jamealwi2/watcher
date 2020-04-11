import requests
import json
import time

driver_file="/root/watcher/scrape/drivers.txt"
mesos_cluster="http://mesos-cluster:5050"

def scrape_frameworks() :
    fdriver = open(driver_file,"w")
    frameworks = requests.get(mesos_cluster+"/frameworks")
    for fw in frameworks.json()['frameworks'] :
        if(fw['name'] == "app-1"):
            fmwrk_id=fw['tasks'][0]['framework_id']
            fdriver.write(fw['webui_url'] + "/api/v1/applications/"+ fmwrk_id + "#app-1#"+fmwrk_id+"\n")
        elif(fw['name'] == "app-2"):
            fmwrk_id=fw['tasks'][0]['framework_id']
            fdriver.write(fw['webui_url'] + "/api/v1/applications/"+ fmwrk_id + "#app-2#"+fmwrk_id+"\n")
        elif(fw['name'] == "app-3"):
            fmwrk_id=fw['tasks'][0]['framework_id']
            fdriver.write(fw['webui_url'] + "/api/v1/applications/"+ fmwrk_id + "#app-3#"+fmwrk_id+"\n")
    fdriver.close()

try:
    scrape_frameworks()
except:
    print("An exception occurred in scrape_frameworks()")
