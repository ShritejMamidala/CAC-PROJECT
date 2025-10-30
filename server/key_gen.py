from livekit import api
import os

# Set your LiveKit API credentials
api_key = "APICJEYBYYxBpQD"
api_secret = "JTQzxopnBBAyjTXo8J4cXDLe4c6FeC9cF3LfuwbyjMeA"

# Define room and participant details
room_name = 'blindside-room'
participant_name = 'guardian-user'

# Generate the access token
token = api.AccessToken(api_key, api_secret) \
    .with_identity(participant_name) \
    .with_grants(api.VideoGrants(room_join=True, room=room_name)) \
    .to_jwt()

print("Generated Token:", token)