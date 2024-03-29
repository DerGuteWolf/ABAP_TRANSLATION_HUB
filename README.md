# ABAP_TRANSLATION_HUB
[![REUSE status](https://api.reuse.software/badge/github.com/DerGuteWolf/ABAP_TRANSLATION_HUB)](https://api.reuse.software/info/github.com/DerGuteWolf/ABAP_TRANSLATION_HUB)

## Description
A ABAP Report called zpush_pull_translation_hub which allows automated upload of object lists for translation to and download of the translations from [SAP Translation Hub Service](https://help.sap.com/viewer/p/SAP_TRANSLATION_HUB) .

## Report Parameters
- Source Language: Original Language of your ABAP Objects and Source Language of the Translation Hub Project (Needs to Match!)
- Target Languages: All or a Subset of the Target Languages of the Translation Hub Project (All Languages need to exist in your SAP System!)
- Object List Name: The most current Object List with this Name is used as the Source (ie eg which was created from the last `RS_LXE_EVALUATION_SCHEDULE` run)
- Server Directory: Directory on the Application Server to use for Intermediate Files (Files will be Automatically Deleted after Usage, so no Accumulation of Files in this Directory), needs to be Allowed for Translation Externalization Usage: in Transaction `FILE` under "Logical File Name Definition, Cross Client" the Entry `BC_T9N_EXT` Maps by Default to Logical Path `TRANSLATION`, which you thus Need to Assign at Least One Physical Path for the Operation System of the Application Server (also in Transaction `FILE`), Use One of these Assigned Paths as the Parameter value
- Destination: HTTP Destination (ie Type `G`) to Translation Hub Tenant
  - As Hostname (cf also [Building Base URL of SAP Translation Hub](https://help.sap.com/viewer/ed6ce7a29bdd42169f5f0d7868bce6eb/Cloud/en-US/3a011fba82644259a2cc3c919863f4b4.html) ) for
    - Enterprise accounts use `sap<technical name of provider subaccount>-<technical name of subscription subaccount>.<region host>`
    - Trial accounts use `saptranslation-<technical name of subaccount>.hanatrial.ondemand.com`
  - As Service No/Port use 443
  - No Path Prefix!
  - Proxy as Needed
  - Basic Authentication with an User (normally a S-User) with Sufficient Priviledges in the Translation Hub Tenant - If you already have a SAP Universal ID, pay attention to Note [3085908](https://launchpad.support.sap.com/#/notes/3085908) and use your account password and not your Universal ID password if they differ.
  - SSL set to Active
  - Use a Cert List which Contains an Appropriate Root CA for SAP BTP (formally known as SCP)
  - You might Want to Restrict the Usage of this Destination with the Help of an "Authorization for Destination" Entry, since it Contains Credentials
  - HTTP 1.1 and Compression for Both Directions should be Actived, All Cookies Need to be Accepted
- Project ID: The \<translation project ID> of a File Translation Project for ABAP xliff Style Properties Files
- External ID: The externalization ID (Numeric Value) used in the Filename in the File Translation Project (Can be Choosen Arbitrarily, can be Used to Translate Texts from Different ABAP Systems in one Translation Project, you should Ensure each Combination of ABAP System and Object List Name has its Unique ID)

## Prerequisites
Note 3088809 (and its dependency note 3081862) needs to be installed.

## Usage
Intended to be run as a job with a variant after a `RS_LXE_EVALUATION_SCHEDULE` job has finished his work (This job starts several more jobs, so unfortunatly "after" scheduling is not really possible, use some appropriate start time differences) but can also be run interactivly.

Should work on a NetWeaver 7.40 and higher, needs /UI2/CL_JSON eg from [2904870 - /UI2/CL_JSON corrections - PL14](https://launchpad.support.sap.com/#/notes/2904870) which needs a SAP_UI version which is in maintenance.

## How to obtain support
In case you need any support, please create a GitHub issue.

## License
This work is dual-licensed under Apache 2.0 and the Derived Beer-ware License. The official license will be Apache 2.0 but finally you can choose between one of them if you use this work.

When you like this stuff, buy @DerGuteWolf a beer.

## Release History
See [CHANGELOG.md](CHANGELOG.md).

## See also https://github.com/DerGuteWolf/ui5-task-translationhub
