import requests
from homeassistant.components.fan import (
    SPEED_HIGH,
    SPEED_LOW,
    SPEED_MEDIUM,
    SPEED_OFF,
)

HASpeedToAPI = {
    SPEED_HIGH: "high",
    SPEED_LOW: "medium",
    SPEED_MEDIUM: "low",
    SPEED_OFF: "stop",
}


class APIError(Exception):
    """Generic catch-all exception."""

    pass


class DeviceApi:
    def __init__(self, host, channel=None):
        self.host = host
        self.channel = channel

    def _get(self, path):
        try:
            url = "http://%s%s" % (self.host, path)
            # print("GET %s" % url)
            res = requests.get(url, timeout=5)
            if res.status_code != 200:
                raise APIError("Invalid status code:" + str(res.status_code))

            result = res.json()
            if not result.get("success"):
                raise APIError("Invalid response: " + res.text)

            return True
        except (requests.exceptions.Timeout, requests.exceptions.ConnectionError) as e:
            raise APIError(str(e))

    def ping(self):
        return self._get("/ping")

    def turn_on_fan(self, speed):
        return self._get("/%s/%s" % (self.channel, HASpeedToAPI.get(speed, "stop")))

    def turn_off_fan(self):
        return self._get("/%s/stop" % (self.channel))

    def toggle_light(self):
        return self._get("/%s/light" % (self.channel))
