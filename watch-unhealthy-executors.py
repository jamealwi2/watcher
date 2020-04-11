import os
import random
import requests
import json
import time

stages_file="/root/watcher/scrape/stages.txt"
driver_file="/root/watcher/scrape/drivers.txt"

app_1="app-1"
app_2="app-2"
app_3="app-3"

def collect_jstacks(app, process_id, hostID) :
    print("Collecting jstacks...")
    app_id=""
    if (app == "app-1"):
        app_id = "app-1"
    elif (app == "app-3"):
        app_id = "app-3"
    elif (app == "app-2"):
        app_id = "app-2"
    os.system("/usr/bin/jstack-kill-process.sh %s %s %s false" % (app_id, process_id, hostID))

def initiate_process_kill(driver):
    max_processs = 3
    process_count = 0
    app = driver.split('#')[1]
    processs = requests.get(driver.split('#')[0]+"/processs").json()
    for process in processs:
        activeTasks = process['activeTasks']
        if (activeTasks != 0 and process_count < max_processs):
            process_count = process_count+1
            process_id = process['id']
            hostID = process['hostPort'].split(':')[0].rstrip()
            collect_jstacks(app, process_id, hostID)


def scrape_active_stages():
    active_stages = {}
    fstages = open(stages_file, "r")
    for stages in fstages:
        framework_id = stages.split('#')[0].rstrip()
        app_name = stages.split('#')[1].rstrip()
        stageID = stages.split('#')[2].rstrip()
        active_stages[framework_id+"#"+app_name] = stageID
    fstages.close()

    fstages = open(stages_file, "w")
    fdriver = open(driver_file, "r")
    for drivers in fdriver:
        app_name = drivers.split('#')[1].rstrip()
        framework_id = drivers.split('#')[2].rstrip()
        stages = requests.get(drivers.split('#')[0]+'/stages?status=active').json()
        for stage in stages:
            stageId = stage['stageId']
            key = framework_id+"#"+app_name
            previousStageId = -1
            if key in active_stages:
                previousStageId = active_stages[key]
            if (str(stageId).rstrip() == str(previousStageId).rstrip()) :
                initiate_process_kill(drivers)
            fstages.write(framework_id+"#"+app_name+"#"+str(stageId)+"\n")
    fdriver.close()
    fstages.close()

scrape_active_stages()
