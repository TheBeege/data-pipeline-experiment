import os
import pathlib
from datetime import datetime

import pkg_resources
from prefect.storage import Docker
from flow_twitter_data import flow as twitter_flow

# Parse and format dependencies
with pathlib.Path(f'{os.path.dirname(__file__)}/requirements.txt').open() as requirements_txt:
    dependencies = [
        str(requirement)
        for requirement
        in pkg_resources.parse_requirements(requirements_txt)
        if 'prefect' not in str(requirement)
    ]
print(dependencies)

# Create our Docker storage
print(f'{datetime.utcnow()} - Creating storage')
storage = Docker(
    registry_url="localhost:5001",
    image_name="twitter-data-science",
    image_tag="latest",
    python_dependencies=dependencies,
)

# Add both Flows to storage
print(f'{datetime.utcnow()} - Adding flow to storage')
storage.add_flow(twitter_flow)

# Build the storage
print(f'{datetime.utcnow()} - Building storage')
storage = storage.build()

# Reassign the new storage object to each Flow
print(f'{datetime.utcnow()} - Setting storage for flow')
twitter_flow.storage = storage

# Register each flow without building a second time
print(f'{datetime.utcnow()} - Registering flow')
twitter_flow.register(project_name="twitter-pipeline", build=False)
