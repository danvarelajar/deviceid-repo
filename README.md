# Device ID+ Proof Of Value

This repository contains the elements needed to run a quick POV of DeviceID+. You can find details about DeviceID+ [here](https://f5cloudservices.zendesk.com/hc/en-us/articles/360058428514-About-F5-Device-ID-)  and the two identiafiers aproach (diA and diB) [here](https://f5cloudservices.zendesk.com/hc/en-us/articles/360060250913). 
The idea is to integrate DeviceID+ in an application, collect device information and send it to a small containarized ELK where we display and correlate information.

For the ELK container image you can create your own using the Dockerfile or you can use a ready one in Docker Hub: danivarela/elk-did:1.6. The image runs with a minimum of 2vCPUs and 4GiB, depending of the ammount of traffic to analyze you may require more resources. For easiness you can use docker in a Linux host, if you need to install it you can find [here](https://docs.docker.com/engine/install/) how to do it. 
Before we start, add the following line into /etc/sysctl.conf on your host.
```
vm.max_map_count=262144
```
Then
```
sudo sysctl -p
````

Run the docker image (replace with your own image if using your own image and a private repository):
````
docker run -d -p 5044:5044 -p 5601:5601 -p 1513-1515:1513-1515/tcp -p 9200:9200 -p 9600:9600 --name elk danivarela/elk-did:1.8
````

Access ELK at http://your_ip:5601. In order to get all the visualization you need to import some objects, this is in export.ndjson file:

 - go to the Menu and click on stack management at the bottom.
 - click on Saved objects and import the file export.ndjson.

![alt text](https://github.com/danvarelajar/deviceid-repo/blob/main/Images/kibana_menu.png?raw=true) ![alt text](https://github.com/danvarelajar/deviceid-repo/blob/main/Images/kibana_stack_mgmt_index_patterns.png?raw=true)

 From this point the ELK is ready to receive logs, go to Dashboard and you will see the one preconfigured to display Device ID information.

![alt text](https://github.com/danvarelajar/deviceid-repo/blob/main/Images/menu_dashboard.png?raw=true) 

![alt text](https://github.com/danvarelajar/deviceid-repo/blob/main/Images/dashboard.png?raw=true) 

 ####

In order to get access to DeviceID+ you must create an account in Volterra, go to system and Shape Device ID.

![alt text](https://github.com/danvarelajar/deviceid-repo/blob/main/Images/volterra_device_ID.png?raw=true)

Enable this feature and then start by clicking on add applications. There are several ways to add Device ID onto applications but we will use iApps. Follow the wizard to get the latest iApp and Device ID JS that will be used later on.

![alt text](https://github.com/danvarelajar/deviceid-repo/blob/main/Images/did_wizard.png?raw=true)

On your BIG-IP import the iApp in iApps > Templates > Templates, to deploy the iApp go to iApps > Application Services > Applications and click on Create. Add the JS you got from Volterra Shape Device ID and select the Virtual Server where you want to add Device ID.

Image![alt text](https://github.com/danvarelajar/deviceid-repo/blob/main/Images/iapp_screenshot.png?raw=true)

Note: Device ID requires connection to the internet, verify your BIG-IP have access.

Once the iApp is deployed you will need to import an irule (did_logging.irule in this repo) to enable HSL logging and send the details about devices and usernames. This irule needs to be attached directly in the virtual server where you enabled DeviceID+ and needs to be in the top of the list of irules (at least above the irule the iApp added) As we capture the login form username and this will vary between applications, we have tried to capture the most common use cases and for that there are some things we need to change at the begining of the irule:

 - set login_uri, logout_uri and username_form_name (this is the paramenter name that is sent in the POST for the username) accordingly. Review the application for this, it will require some inspection but it is an easy task.
 - set check content to 1 if you expect the application to respond with a page and specific content when the user authenticates successfuly. Set login_failed to the expected string to detect a login failed.
 - set check_redirect to 1 if you detect successful login by looking at the http response redirect. Set location_string to the exact redirect string sent by the server.

 Last, create a pool with name ELK and member ELK ip address and port 1514.

 After all the steps you are ready to enjoy Device ID+.
 
 # Device ID+ with Advanced WAF

In case you are deploying Device ID+ with Advanced WAF then the configuration changes a little bit. 
 - There is no need to deploy the irule or create the ELK pool. We just neet to create a logging profile that logs all requests with the maximum request size and with splunk format. This logging profile will point to the ELK container IP on port 1515/tcp.
 - Add the logging profile to the virtual server with the security policy you would like to get Device ID+ insights.
 - There are additionals element we need to configure in ELK:
   - Ingest Node Pipelines: In stack management go to Ingest Node Pipelines and create a new one. Name it "ingest-slat" and import the following processor, then click on create:
```
{
  "processors": [
    {
      "convert": {
        "field": "geoip.location.lon",
        "type": "string",
        "target_field": "location.lon",
        "ignore_missing": true,
        "ignore_failure": true
      }
    },
    {
      "convert": {
        "field": "geoip.location.lat",
        "type": "string",
        "target_field": "location.lat",
        "ignore_missing": true,
        "ignore_failure": true
      }
    }
  ]
}
```
   - Create a new index template: Go to stack management, index management and click in index templates. Create a new one and follow the steps. Name it "template_slat" and set index pattern as slat.logs-*. Skip component templates. On index setting paste the following code
```
{
  "index": {
    "default_pipeline": "ingest-slat"
  }
}
```
   - On mappings select load JSON and paste the following code:
```
{
  "properties": {
    "@timestamp": {
      "type": "date"
    },
    "source_host": {
      "index": true,
      "store": false,
      "type": "ip",
      "doc_values": true
    },
    "location": {
      "type": "geo_point"
    }
  }
}
```
   - follow the steps and leave them as default. Finish by clicking on create at the last step.
   - Lastly go to stack management, saved object and click import to load export_waf-did.ndjson files and get the WAF-DID dashboard.

###
