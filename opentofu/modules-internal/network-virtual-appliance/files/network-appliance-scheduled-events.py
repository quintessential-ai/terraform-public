#!/usr/bin/env python3
"""Drains this instance before Azure deletes, reboots or redeploys it, then lets the event start early.

Azure announces these events through the instance metadata service.
https://learn.microsoft.com/en-us/azure/virtual-machines/linux/scheduled-events
"""

import json
import logging
import subprocess
import sys
import time
import urllib.request

METADATA_URL = "http://169.254.169.254/metadata"
EVENTS_URL = f"{METADATA_URL}/scheduledevents?api-version=2020-07-01"
INSTANCE_NAME_URL = (
    f"{METADATA_URL}/instance/compute/name?api-version=2021-02-01&format=text"
)

DISRUPTIVE_EVENT_TYPES = {"Terminate", "Reboot", "Redeploy", "Preempt"}
"""Events that stop the instance. Freeze pauses it for seconds and keeps its connections."""

POLL_SECONDS = 5

REQUEST_TIMEOUT_SECONDS = 120
"""The first request turns scheduled events on for the instance, which can take two minutes."""

logger = logging.getLogger("network-appliance-scheduled-events")


def request_metadata(url: str, body: bytes | None = None) -> bytes:
    request = urllib.request.Request(url, data=body, headers={"Metadata": "true"})  # noqa: S310 - a constant metadata URL
    with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:  # noqa: S310 - a constant metadata URL
        return response.read()


def disruptive_events_for(instance_name: str) -> list[dict]:
    document = json.loads(request_metadata(EVENTS_URL))
    events = []
    for event in document["Events"]:
        is_disruptive = event["EventType"] in DISRUPTIVE_EVENT_TYPES
        is_ours = instance_name in event["Resources"]
        if is_disruptive and is_ours and event["EventStatus"] == "Scheduled":
            events.append(event)
    return events


def main() -> None:
    logging.basicConfig(level=logging.INFO)
    grace_seconds = sys.argv[1]
    instance_name = request_metadata(INSTANCE_NAME_URL).decode()
    # Once drained, the instance stays drained. If Azure cancels the event, the failing probe gets
    # the instance replaced by the scale set's automatic repair.
    drained = False
    while True:
        try:
            events = disruptive_events_for(instance_name)
            if events and not drained:
                logger.info("Draining for %s", [event["EventType"] for event in events])
                drain_command = [
                    "/usr/local/bin/network-appliance-drain",
                    grace_seconds,
                ]
                subprocess.run(drain_command, check=True)  # noqa: S603 - a fixed command
                drained = True
            if events:
                approval = {
                    "StartRequests": [{"EventId": event["EventId"]} for event in events]
                }
                request_metadata(EVENTS_URL, json.dumps(approval).encode())
        except Exception as error:  # noqa: BLE001 - a failed poll is retried, never fatal
            logger.warning("Scheduled events poll failed: %s", error)
        time.sleep(POLL_SECONDS)


main()
