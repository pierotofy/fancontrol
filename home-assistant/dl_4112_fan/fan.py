"""Platform for light integration."""
import logging

# import awesomelights
import voluptuous as vol

import homeassistant.helpers.config_validation as cv
from homeassistant.const import CONF_HOST
from .api import DeviceApi, APIError

from homeassistant.components.fan import (
    SPEED_HIGH,
    SPEED_LOW,
    SPEED_MEDIUM,
    SPEED_OFF,
    SUPPORT_SET_SPEED,
    FanEntity,
    PLATFORM_SCHEMA,
)

from homeassistant.components.switch import SwitchEntity

_LOGGER = logging.getLogger(__name__)

DOMAIN = "dl_4112_fan"

# Validation of the user's configuration
PLATFORM_SCHEMA = PLATFORM_SCHEMA.extend(
    {
        vol.Required(CONF_HOST): cv.string,
        vol.Required("fans"): vol.All(cv.ensure_list, [cv.string]),
    }
)


def setup_platform(hass, config, add_entities, discovery_info=None):
    """Set up the Awesome Light platform."""
    # Assign configuration variables.
    # The configuration check takes care they are present.
    host = config[CONF_HOST]
    fans = config["fans"]

    d = DeviceApi(host)
    try:
        d.ping()
    except APIError as e:
        _LOGGER.error("Could not connect to DL4112 fan control: " + str(e))
        return

    # Add devices
    add_entities(DL4112Fan(host, fan) for fan in fans)
    add_entities(DL4112LightSwitch(host, fan) for fan in fans)


class DL4112Fan(FanEntity):
    """DL-4112 Fan Remote."""

    def __init__(self, host, fan):
        """Initialize."""
        name, channel = fan.split(":")
        self._channel = channel
        self._name = name + " Fan"
        self._state = None
        self._speed = SPEED_OFF
        self._api = DeviceApi(host, self._channel)

    @property
    def assumed_state(self):
        return True

    @property
    def name(self):
        """Return the display name of this light."""
        return self._name

    @property
    def is_on(self):
        """Return true if fan is on."""
        return self._state

    @property
    def speed_list(self) -> list:
        """Get the list of available speeds."""
        return [SPEED_OFF, SPEED_LOW, SPEED_MEDIUM, SPEED_HIGH]

    @property
    def speed(self) -> str:
        """Return the current speed."""
        return self._speed

    @property
    def supported_features(self) -> int:
        """Flag supported features."""
        return SUPPORT_SET_SPEED

    def set_speed(self, speed: str) -> None:
        """Set the speed of the fan."""
        self._speed = speed
        print("SET SPEED")

    def turn_off(self, **kwargs) -> None:
        """Turn the fan off."""
        self._state = None
        self._api.turn_off_fan()

    def turn_on(self, speed, **kwargs) -> None:
        """Turn the fan on."""
        self._state = True
        self._speed = speed
        self._api.turn_on_fan(self._speed)


class DL4112LightSwitch(SwitchEntity):
    """DL-4112 Fan Remote Light Switch."""

    def __init__(self, host, fan):
        """Initialize."""
        name, channel = fan.split(":")
        self._channel = channel
        self._name = name + " Fan Light"
        self._state = None
        self._api = DeviceApi(host, self._channel)

    @property
    def assumed_state(self):
        return True

    @property
    def icon(self):
        return "mdi:lightbulb"

    @property
    def name(self):
        """Return the display name of this light."""
        return self._name

    @property
    def is_on(self):
        """Return true if fan is on."""
        return self._state

    def turn_off(self, **kwargs) -> None:
        """Turn the light off."""
        self._state = None
        self._api.toggle_light()

    def turn_on(self, **kwargs) -> None:
        """Turn the light on."""
        self._state = True
        self._api.toggle_light()