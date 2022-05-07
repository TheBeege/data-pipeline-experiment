import json
import os
import urllib.parse

import prefect
from prefect import task, Flow
import requests
import mysql.connector


@task(log_stdout=True)
def retrieve_tweets():
    logger = prefect.context.get("logger")
    auth_token = os.getenv('TWITTER_BEARER_TOKEN')
    logger.info('about to request tweets')
    response = requests.get(
        'https://api.twitter.com/2/tweets/search/recent',
        params={
            'query': '"data science" has:links',
            'tweet.fields': 'entities',
            'max_results': '10',
        },
        headers={
            'Authorization': f'Bearer {auth_token}',
        },
    )
    results = response.json()
    print(json.dumps(results))
    logger.info(f'got {len(results["data"])} tweets')
    return results


@task(log_stdout=True)
def transform_data(response):
    logger = prefect.context.get("logger")
    logger.info('transforming tweet data')
    hostname_counts = {}
    for tweet in response['data']:
        if 'urls' in tweet['entities']:
            for url in tweet['entities']['urls']:
                if 'unwound_url' in url:
                    hostname = urllib.parse.urlparse(url['unwound_url']).hostname
                else:
                    hostname = urllib.parse.urlparse(url['expanded_url']).hostname

                # this hostname has been seen before
                if hostname in hostname_counts:
                    # so we increase its count by 1
                    hostname_counts[hostname] += 1
                # this hostname has not been seen before
                else:
                    # this is the first time seeing it, so set the count to 1
                    hostname_counts[hostname] = 1
    logger.info(f'reformatted {len(hostname_counts)} records')
    logger.info(f'hostname_counts: {json.dumps(hostname_counts)}')
    return hostname_counts


@task(log_stdout=True)
def store_data(records):
    logger = prefect.context.get("logger")
    logger.info('connecting to database')
    connection = mysql.connector.connect(
        host="database",
        user="root",
        password="testdb",
        database="twitter"
    )
    cursor = connection.cursor()
    sql = 'insert into tweets(id, text) values (%s, %s)'
    logger.info('inserting tweet data')
    # executemany has an optimization for inserts where it converts multiple
    # individual insert statements into a multi-record insert
    cursor.executemany(sql, records)
    connection.commit()


with Flow("Twitter data") as flow:
    tweets = retrieve_tweets()
    formatted_data = transform_data(tweets)
    # store_data(formatted_data)


flow.run()
