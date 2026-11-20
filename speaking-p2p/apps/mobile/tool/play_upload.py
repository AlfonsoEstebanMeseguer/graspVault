"""Upload an .aab to a Google Play track (D-068). Used by .github/workflows/speaking-p2p-play.yml.

  python3 tool/play_upload.py <aab> <track> <status>

Reads the service account JSON from PLAY_SERVICE_ACCOUNT_JSON (never printed). Status "draft" is
required while the app has never been published; afterwards "completed" rolls it out to testers.
"""
import json
import os
import sys

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

PACKAGE = "com.speakingp2p.speaking_p2p"


def main() -> None:
    aab, track, status = sys.argv[1:4]
    creds = service_account.Credentials.from_service_account_info(
        json.loads(os.environ["PLAY_SERVICE_ACCOUNT_JSON"]),
        scopes=["https://www.googleapis.com/auth/androidpublisher"],
    )
    edits = build("androidpublisher", "v3", credentials=creds, cache_discovery=False).edits()
    edit_id = edits.insert(packageName=PACKAGE, body={}).execute()["id"]
    bundle = edits.bundles().upload(
        packageName=PACKAGE,
        editId=edit_id,
        media_body=MediaFileUpload(aab, mimetype="application/octet-stream", resumable=True),
    ).execute()
    code = bundle["versionCode"]
    edits.tracks().update(
        packageName=PACKAGE,
        editId=edit_id,
        track=track,
        body={"track": track, "releases": [{"versionCodes": [str(code)], "status": status}]},
    ).execute()
    edits.commit(packageName=PACKAGE, editId=edit_id).execute()
    print(f"versionCode {code} -> {track} ({status})")


if __name__ == "__main__":
    main()
