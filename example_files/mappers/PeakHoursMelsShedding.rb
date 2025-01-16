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
    class PeakHoursMelsSheddingMapper < BaselineMapper
      # The measure reduces electric equipment loads by a user-specified percentage for a user-specified time period (usually the peak hours).
      # The reduction can be applied to at most three periods throughout out the year specified by the user.
      # This is applied throughout the entire building.
      def create_osw(scenario, features, feature_names)
        osw = super(scenario, features, feature_names)
        OpenStudio::Extension.set_measure_argument(osw, 'reduce_epd_by_percentage_for_peak_hours', '__SKIP__', false)
        # Percentage Reduction of Electric Equipment Power (%). Enter a value between 0 and 100
        OpenStudio::Extension.set_measure_argument(osw, 'reduce_epd_by_percentage_for_peak_hours', 'epd_reduce_percent', 50.0)
        # Starting Time for the Reduction in HH:MM:SS format
        OpenStudio::Extension.set_measure_argument(osw, 'reduce_epd_by_percentage_for_peak_hours', 'start_time1', '17:00:00')
        # End Time for the Reduction in HH:MM:SS format
        OpenStudio::Extension.set_measure_argument(osw, 'reduce_epd_by_percentage_for_peak_hours', 'end_time1', '21:00:00')

        # First Starting Date for the Reduction in MM-DD format
        OpenStudio::Extension.set_measure_argument(osw, 'reduce_epd_by_percentage_for_peak_hours', 'start_date1', '07-01')
        # First End Date for the Reduction in MM-DD format
        OpenStudio::Extension.set_measure_argument(osw, 'reduce_epd_by_percentage_for_peak_hours', 'end_date1', '08-31')
        # Second Starting Date for the Reduction in MM-DD format. Leave it blank if not needed
        # OpenStudio::Extension.set_measure_argument(osw, 'reduce_epd_by_percentage_for_peak_hours', 'start_date2', '')
        # Second End Date for the Reduction in MM-DD format. Leave it blank if not needed
        # OpenStudio::Extension.set_measure_argument(osw, 'reduce_epd_by_percentage_for_peak_hours', 'end_date2', '')
        # Third Starting Date for the Reduction in MM-DD format. Leave it blank if not needed
        # OpenStudio::Extension.set_measure_argument(osw, 'reduce_epd_by_percentage_for_peak_hours', 'start_date3', '')
        # Third End Date for the Reduction in MM-DD format. Leave it blank if not needed
        # OpenStudio::Extension.set_measure_argument(osw, 'reduce_epd_by_percentage_for_peak_hours', 'end_date3', '')
        return osw
      end
    end
  end
end
