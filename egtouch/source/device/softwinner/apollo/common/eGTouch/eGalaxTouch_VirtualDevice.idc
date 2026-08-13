# Copyright (C) 2010 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# Input Device Calibration File for the EETI touch screen.
#
# These calibration values are derived from empirical measurements
# and may not be appropriate for use with other touch screens.
# Refer to the input device calibration documentation for more details.
#

# Basic Parameters
touch.deviceType = touchScreen
#touch.orientationAware = 1

# Touch Size
touch.touchSize.calibration = default

# Tool Size
touch.toolSize.calibration = default

# Pressure
touch.pressure.calibration = default

# Size
touch.size.calibration = default

# Orientation
touch.orientation.calibration = none

# The value is 0, the device is external.
# The value is 1, the device is internal.
# Internal input devices generally do not wake the display from sleep.
# Unless explicitly configured to do so in the key layout file or in a hardcoded policy rule. 
device.internal = 0

