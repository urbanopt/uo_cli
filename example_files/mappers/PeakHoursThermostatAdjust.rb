# *********************************************************************************
# URBANopt (tm), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-cli/blob/develop/LICENSE.md
# *********************************************************************************

# Mapper created by LBNL using the measure from openstudio-geb gem
# (https://github.com/LBNL-ETA/Openstudio-GEB-gem)
# *********************************************************************************

require 'urbanopt/reporting'
require 'openstudio/geb'

require_relative 'Baseline'

require 'json'

module URBANopt
  module Scenario
    class PeakHoursThermostatAdjustMapper < BaselineMapper
      # The measure adjusts heating and cooling setpoints by a user-specified number of degrees and a user-specified time period.
      # This is applied throughout the entire building.
      def create_osw(scenario, features, feature_names)
        osw = super(scenario, features, feature_names)
        OpenStudio::Extension.set_measure_argument(osw, 'AdjustThermostatSetpointsByDegreesForPeakHours', '__SKIP__', false)
        # Degrees Fahrenheit to Adjust Cooling Setpoint By
        OpenStudio::Extension.set_measure_argument(osw, 'AdjustThermostatSetpointsByDegreesForPeakHours', 'cooling_adjustment', 2.0)
        # Daily Start Time for Cooling Adjustment. Use 24 hour format HH:MM:SS
        OpenStudio::Extension.set_measure_argument(osw, 'AdjustThermostatSetpointsByDegreesForPeakHours', 'cooling_start_time1', '16:01:00')
        # Daily End Time for Cooling Adjustment. Use 24 hour format HH:MM:SS
        OpenStudio::Extension.set_measure_argument(osw, 'AdjustThermostatSetpointsByDegreesForPeakHours', 'cooling_end_time1', '20:00:00')
        # Start Date for Cooling Adjustment in MM-DD format
        OpenStudio::Extension.set_measure_argument(osw, 'AdjustThermostatSetpointsByDegreesForPeakHours', 'cooling_start_date1', '06-01')
        # End Date for Cooling Adjustment in MM-DD format
        OpenStudio::Extension.set_measure_argument(osw, 'AdjustThermostatSetpointsByDegreesForPeakHours', 'cooling_end_date1', '09-30')

        # Degrees Fahrenheit to Adjust Heating Setpoint By
        OpenStudio::Extension.set_measure_argument(osw, 'AdjustThermostatSetpointsByDegreesForPeakHours', 'heating_adjustment', -2.0)
        # Daily Start Time for Heating Adjustment. Use 24 hour format HH:MM:SS
        OpenStudio::Extension.set_measure_argument(osw, 'AdjustThermostatSetpointsByDegreesForPeakHours', 'heating_start_time1', '18:01:00')
        # Daily End Time for Heating Adjustment. Use 24 hour format HH:MM:SS
        OpenStudio::Extension.set_measure_argument(osw, 'AdjustThermostatSetpointsByDegreesForPeakHours', 'heating_end_time1', '22:00:00')
        # Start Date for Heating Adjustment Period 1 in MM-DD format
        OpenStudio::Extension.set_measure_argument(osw, 'AdjustThermostatSetpointsByDegreesForPeakHours', 'heating_start_date1', '01-01')
        # End Date for Heating Adjustment Period 1 in MM-DD format
        OpenStudio::Extension.set_measure_argument(osw, 'AdjustThermostatSetpointsByDegreesForPeakHours', 'heating_end_date1', '05-31')
        # Start Date for Heating Adjustment Period 2 in MM-DD format
        OpenStudio::Extension.set_measure_argument(osw, 'AdjustThermostatSetpointsByDegreesForPeakHours', 'heating_start_date2', '10-01')
        # End Date for Heating Adjustment Period 2 in MM-DD format
        OpenStudio::Extension.set_measure_argument(osw, 'AdjustThermostatSetpointsByDegreesForPeakHours', 'heating_end_date2', '12-31')

        return osw
      end
    end
  end
end
