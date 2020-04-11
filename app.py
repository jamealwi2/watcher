import flask
from flask import request, jsonify
import os

app = flask.Flask(__name__)
app.config["DEBUG"] = True

base_dir=${BASE_DIRECTORY}

@app.route('/', methods=['GET'])
def home():
    last_thread_dump=open(base_dir+"/.last-threaddump","r")
    for ltime in last_thread_dump:
        print("in")
    lttime = ltime
    last_thread_dump.close()
    return '''<body style="background-color:#EDF8FA;"><h2 style="color:white; background-color:#4267B2;">Application Watcher</h2>
<br><hr><br><a href="http://application.watcher/api/v1/prod/status">Am I Watching or Sleeping?</a><br><br>
<a href="http://application.watcher/api/v1/prod/enable">Enable</a> Let's find the culprit!  <br><br>
<a href="http://application.watcher/api/v1/prod/disable">Disable</a> Enough, let me sleep for a while. <br><br><br>
<p style="font-style:italic; color:gray; font-size:13px; "> I caught you last on ''' + lttime +'''</p></body>'''


@app.route('/api/v1/prod/enable', methods=['GET'])
def enable_monitor_prod():
    status_prod = open(base_dir+"/.prod.status","w")
    status_prod.write('true')
    status_prod.close()
    os.system("/usr/bin/monitor-status-slack-alert")
    return "Watcher enabled"

@app.route('/api/v1/prod/disable', methods=['GET'])
def disable_monitor_prod():
    status_prod = open(base_dir+"/.prod.status","w")
    status_prod.write('false')
    status_prod.close()
    os.system("/usr/bin/monitor-status-slack-alert")
    return "Watcher disabled"

@app.route('/api/v1/prod/status', methods=['GET'])
def check_status_prod():
    status_prod = open(base_dir+"/.prod.status","r")
    status = "INACTIVE"
    for entry in status_prod:
        if (entry == "true"):
            status = "ACTIVE"
    status_prod.close()
    return status

app.run()
