import os

import prefect
from prefect import task, Flow
import requests
import mysql.connector
import json


@task(log_stdout=True)
def retrieve_tweets():
    logger = prefect.context.get("logger")
    auth_token = os.getenv('TWITTER_BEARER_TOKEN')
    logger.info('about to request tweets')
    tweet_fields_to_fetch = [
        'conversation_id'
    ]
    user_fields_to_fetch = [
        'username'
    ]
    response = requests.get(
        'https://api.twitter.com/2/tweets/search/recent',
        params={
            'query': '#ufc is:verified',
            'max_results': '10',
            'user.fields': ','.join(user_fields_to_fetch),
            'tweet.fields': ','.join(tweet_fields_to_fetch),
            'expansions': 'author_id',
        },
        headers={
            'Authorization': f'Bearer {auth_token}',
        },
    )
    results = response.json()
    logger.info(f'got {len(results["data"])} tweets')
    return results


@task(log_stdout=True)
def transform_data(response):
    logger = prefect.context.get("logger")
    logger.info('transforming tweet data')
    data = []
    try:
        for tweet in response['data']:
            for user in response['includes']['users']:
                if tweet['author_id'] == user['id']:
                    username = user['username']
            data.append(
                [
                    tweet['id'],
                    tweet['text'],
                    username,
                    tweet['conversation_id']
                ]
            )
    except KeyError:
        logger.exception(f'failed: {json.dumps(response)}')
    logger.info(f'reformatted {len(data)} records')
    return data


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
    sql = 'insert into tweets(id, text, username, conversation_id) values (%s, %s, %s, %s)'
    logger.info('inserting tweet data')
    # executemany has an optimization for inserts where it converts multiple
    # individual insert statements into a multi-record insert
    cursor.executemany(sql, records)
    connection.commit()


with Flow("Twitter data") as flow:
    tweets = retrieve_tweets()
    formatted_data = transform_data(tweets)
    store_data(formatted_data)


flow.run()
