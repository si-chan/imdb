# imdb-azure

## Overview
A Terraform configuration to create the infrastructure necessary to download the IMDb public data, parse it and make it available as a database to serve up via a small web front-end and basic API service.

The IMDB data is available at:
https://datasets.imdbws.com/

## Components

### Back-end components

* Storage Account - Acts as a temporary download location for the TSV files
* Automation Account - Contains a runbook which downloads and parses the TSV files and loads the data into a CosmosDB along with a schedule to invoke the runbook on a daily basis
* Azure data factory - Runs the import from the blob into the database
* CosmosDB - The database containing the latest IMDb data

### Front-end components

