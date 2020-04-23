# *********************************************************************************
# URBANopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC, and other
# contributors. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
# *********************************************************************************

require 'urbanopt/scenario'
require 'openstudio/common_measures'
require 'openstudio/model_articulation'

require 'json'

module URBANopt
  module Scenario
    class BaselineMapper < SimulationMapperBase
      # class level variables
      @@instance_lock = Mutex.new
      @@osw = nil
      @@geometry = nil

      def initialize
        # do initialization of class variables in thread safe way
        @@instance_lock.synchronize do
          if @@osw.nil?

            # load the OSW for this class
            osw_path = File.join(File.dirname(__FILE__), 'base_workflow.osw')
            File.open(osw_path, 'r') do |file|
              @@osw = JSON.parse(file.read, symbolize_names: true)
            end

            # add any paths local to the project
            @@osw[:measure_paths] << File.join(File.dirname(__FILE__), '../measures/')
            @@osw[:measure_paths] << File.join(File.dirname(__FILE__), '../resources/hpxml-measures')
            @@osw[:file_paths] << File.join(File.dirname(__FILE__), '../weather/')

            # configures OSW with extension gem paths for measures and files, all extension gems must be
            # required before this
            @@osw = OpenStudio::Extension.configure_osw(@@osw)
          end
        end
      end

      def lookup_building_type(building_type, template, footprint_area, number_of_stories)
        if template.include? 'DEER'
          case building_type
          when 'Education'
            return 'EPr'
          when 'Enclosed mall'
            return 'RtL'
          when 'Food sales'
            return 'RSD'
          when 'Food service'
            return 'RSD'
          when 'Inpatient health care'
            return 'Nrs'
          when 'Laboratory'
            return 'Hsp'
          when 'Lodging'
            return 'Htl'
          when 'Mixed use'
            return 'ECC'
          when 'Mobile Home'
            return 'DMo'
          when 'Multifamily (2 to 4 units)'
            return 'MFm'
          when 'Multifamily (5 or more units)'
            return 'MFm'
          when 'Nonrefrigerated warehouse'
            return 'SUn'
          when 'Nursing'
            return 'Nrs'
          when 'Office'
            if footprint_area
              if footprint_area.to_f > 100000
                return 'OfL'
              else
                return 'OfS'
              end
            else
              raise 'footprint_area required to map office building type'
            end
          when 'Outpatient health care'
            return 'Nrs'
          when 'Public assembly'
            return 'Asm'
          when 'Public order and safety'
            return 'Asm'
          when 'Refrigerated warehouse'
            return 'WRf'
          when 'Religious worship'
            return 'Asm'
          when 'Retail other than mall'
            return 'RtS'
          when 'Service'
            return 'MLI'
          when 'Single-Family'
            return 'MFm'
          when 'Strip shopping mall'
            return 'RtL'
          when 'Vacant'
            return 'SUn'
          else
            raise "building type #{building_type} cannot be mapped to a DEER building type"
          end

        else
          # default: ASHRAE
          case building_type
          when 'Education'
            return 'SecondarySchool'
          when 'Enclosed mall'
            return 'RetailStripmall'
          when 'Food sales'
            return 'FullServiceRestaurant'
          when 'Food service'
            return 'FullServiceRestaurant'
          when 'Inpatient health care'
            return 'Hospital'
          when 'Laboratory'
            return 'Hospital'
          when 'Lodging'
            if number_of_stories
              if number_of_stories.to_i > 3
                return 'LargeHotel'
              else
                return 'SmallHotel'
              end
            end
            return 'LargeHotel'
          when 'Mixed use'
            return 'Mixed use'
          when 'Mobile Home'
            return 'MidriseApartment'
          when 'Multifamily (2 to 4 units)'
            return 'MidriseApartment'
          when 'Multifamily (5 or more units)'
            return 'MidriseApartment'
          when 'Nonrefrigerated warehouse'
            return 'Warehouse'
          when 'Nursing'
            return 'Outpatient'
          when 'Office'
            if footprint_area
              if footprint_area.to_f < 20000
                value = 'SmallOffice'
              elsif footprint_area.to_f > 100000
                value = 'LargeOffice'
              else
                value = 'MediumOffice'
              end
            else
              raise 'Floor area required to map office building type'
            end
          when 'Outpatient health care'
            return 'Outpatient'
          when 'Public assembly'
            return 'MediumOffice'
          when 'Public order and safety'
            return 'MediumOffice'
          when 'Refrigerated warehouse'
            return 'Warehouse'
          when 'Religious worship'
            return 'MediumOffice'
          when 'Retail other than mall'
            return 'RetailStandalone'
          when 'Service'
            return 'MediumOffice'
          when 'Single-Family'
            return 'MidriseApartment'
          when 'Strip shopping mall'
            return 'RetailStripmall'
          when 'Vacant'
            return 'Warehouse'
          else
            raise "building type #{building_type} cannot be mapped to an ASHRAE building type"
          end
        end
      end

      def lookup_template_by_year_built(template, year_built)
        if template.include? 'DEER'
          if year_built <= 1996
            return 'DEER 1985'
          elsif year_built <= 2003
            return 'DEER 1996'
          elsif year_built <= 2007
            return 'DEER 2003'
          elsif year_built <= 2011
            return 'DEER 2007'
          elsif year_built <= 2014
            return 'DEER 2011'
          elsif year_built <= 2015
            return 'DEER 2014'
          elsif year_built <= 2017
            return 'DEER 2015'
          elsif year_built <= 2020
            return 'DEER 2017'
          else
            return 'DEER 2020'
          end
        else
          # ASHRAE
          if year_built < 1980
            return 'DOE Ref Pre-1980'
          elsif year_built <= 2004
            return 'DOE Ref 1980-2004'
          elsif year_built <= 2007
            return '90.1-2004'
          elsif year_built <= 2010
            return '90.1-2007'
          elsif year_built <= 2013
            return '90.1-2010'
          else
            return '90.1-2013'
          end
        end
      end

      def residential_building_types
        return [
          'Single-Family Detached',
          'Single-Family Attached',
          'Multifamily'
        ]
      end

      def commercial_building_types
        return [
          'Vacant',
          'Office',
          'Laboratory',
          'Nonrefrigerated warehouse',
          'Food sales',
          'Public order and safety',
          'Outpatient health care',
          'Refrigerated warehouse',
          'Religious worship',
          'Public assembly',
          'Education',
          'Food service',
          'Inpatient health care',
          'Nursing',
          'Lodging',          
          'Strip shopping mall',
          'Enclosed mall',
          'Retail other than mall',
          'Service',
          'Uncovered Parking',
          'Covered Parking',
          'Mixed use'
        ]
      end

      def create_osw(scenario, features, feature_names)
        
        if features.size != 1
          raise "Baseline currently cannot simulate more than one feature."
        end
        feature = features[0]
        feature_id = feature.id
        feature_type = feature.type
        feature_name = feature.name
        if feature_names.size == 1
          feature_name = feature_names[0]
        end

        # deep clone of @@osw before we configure it
        osw = Marshal.load(Marshal.dump(@@osw))

        # now we have the feature, we can look up its properties and set arguments in the OSW
        osw[:name] = feature_name
        osw[:description] = feature_name

        if feature_type == 'Building'
          building_type = feature.building_type

          if residential_building_types.include? building_type

            timesteps_per_hour = 1
            begin
              timesteps_per_hour = feature.timesteps_per_hour
            rescue StandardError
            end

            begin_month = 1
            begin_day_of_month = 1
            end_month = 12
            end_day_of_month = 31
            begin
              begin_month = feature.begin_date[5, 2].to_i
              begin_day_of_month = feature.begin_date[8, 2].to_i
              end_month = feature.end_date[5, 2].to_i
              end_day_of_month = feature.end_date[8, 2].to_i
            rescue StandardError
            end

            begin
              weather_station_epw_filename = feature.weather_filename
            rescue StandardError
            end

            num_units = 1
            case building_type
            when 'Single-Family Detached'
              unit_type = "single-family detached"
            when 'Single-Family Attached'
              num_units = feature.number_of_residential_units
              unit_type = "single-family attached"
            when 'Multifamily'
              num_units = feature.number_of_residential_units
              if num_units < 5
                unit_type = "2-4 unit building"
              else
                unit_type = "5+ unit building"
              end
            end

            num_floors = feature.number_of_stories

            begin
              cfa = feature.floor_area / num_units
            rescue StandardError
              cfa = feature.footprint_area * num_floors / num_units
            end

            wall_height = 8.0
            begin
              wall_height = feature.maximum_roof_height / num_floors
            rescue StandardError
            end

            foundation_type = "SlabOnGrade"
            case feature.foundation_type
            when 'crawlspace - vented'
              foundation_type = "VentedCrawlspace"
            when 'crawlspace - unvented'
              foundation_type = "UnventedCrawlspace"
            when 'basement - unconditioned'
              foundation_type = "UnconditionedBasement"
            when 'basement - conditioned'
              foundation_type = "ConditionedBasement"
            when 'ambient'
              foundation_type = "Ambient"
            end

            attic_type = "flat roof"
            begin
              case feature.attic_type
              when 'attic - vented'
                attic_type = "VentedAttic"
              when 'attic - unvented'
                attic_type = "UnventedAttic"
              when 'attic - conditioned'
                attic_type = "ConditionedAttic"
              end
            rescue StandardError
            end

            num_bedrooms = feature.number_of_bedrooms
            num_bedrooms /= num_units

            system_type = "Residential - furnace and central air conditioner"
            begin
              system_type = feature.system_type
            rescue StandardError
            end

            case system_type
            when 'Residential - electric resistance and no cooling'
              heating_system_type = "ElectricResistance"
              cooling_system_type = "none"
              heat_pump_type = "none"
            when 'Residential - electric resistance and central air conditioner'
              heating_system_type = "ElectricResistance"
              cooling_system_type = "central air conditioner"
              heat_pump_type = "none"
            when 'Residential - electric resistance and room air conditioner'
              heating_system_type = "ElectricResistance"
              cooling_system_type = "room air conditioner"
              heat_pump_type = "none"
            when 'Residential - electric resistance and evaporative cooler'
              heating_system_type = "ElectricResistance"
              cooling_system_type = "evaporative cooler"
              heat_pump_type = "none"
            when 'Residential - furnace and no cooling'
              heating_system_type = "Furnace"
              cooling_system_type = "none"
              heat_pump_type = "none"
            when 'Residential - furnace and central air conditioner'
              heating_system_type = "Furnace"
              cooling_system_type = "central air conditioner"
              heat_pump_type = "none"
            when 'Residential - furnace and room air conditioner'
              heating_system_type = "Furnace"
              cooling_system_type = "room air conditioner"
              heat_pump_type = "none"
            when 'Residential - furnace and evaporative cooler'
              heating_system_type = "Furnace"
              cooling_system_type = "evaporative cooler"
              heat_pump_type = "none"
            when 'Residential - boiler and no cooling'
              heating_system_type = "Boiler"
              cooling_system_type = "none"
              heat_pump_type = "none"
            when 'Residential - boiler and central air conditioner'
              heating_system_type = "Boiler"
              cooling_system_type = "central air conditioner"
              heat_pump_type = "none"
            when 'Residential - boiler and room air conditioner'
              heating_system_type = "Boiler"
              cooling_system_type = "room air conditioner"
              heat_pump_type = "none"
            when 'Residential - boiler and evaporative cooler'
              heating_system_type = "Boiler"
              cooling_system_type = "evaporative cooler"
              heat_pump_type = "none"
            when 'Residential - air-to-air heat pump'
              heating_system_type = "none"
              cooling_system_type = "none"
              heat_pump_type = "air-to-air"
            when 'Residential - mini-split heat pump'
              heating_system_type = "none"
              cooling_system_type = "none"
              heat_pump_type = "mini-split"
            when 'Residential - ground-to-air heat pump'
              heating_system_type = "none"
              cooling_system_type = "none"
              heat_pump_type = "ground-to-air"
            end

            heating_system_fuel = "natural gas"
            begin
              heating_system_fuel = feature.heating_system_fuel_type
            rescue StandardError
            end

            OpenStudio::Extension.set_measure_argument(osw, 'BuildResidentialURBANoptModel', '__SKIP__', false)
            OpenStudio::Extension.set_measure_argument(osw, 'BuildResidentialURBANoptModel', 'timesteps_per_hour', timesteps_per_hour)
            OpenStudio::Extension.set_measure_argument(osw, 'BuildResidentialURBANoptModel', 'begin_month', begin_month)
            OpenStudio::Extension.set_measure_argument(osw, 'BuildResidentialURBANoptModel', 'begin_day_of_month', begin_day_of_month)
            OpenStudio::Extension.set_measure_argument(osw, 'BuildResidentialURBANoptModel', 'end_month', end_month)
            OpenStudio::Extension.set_measure_argument(osw, 'BuildResidentialURBANoptModel', 'end_day_of_month', end_day_of_month)
            OpenStudio::Extension.set_measure_argument(osw, 'BuildResidentialURBANoptModel', 'weather_station_epw_filename', weather_station_epw_filename)
            OpenStudio::Extension.set_measure_argument(osw, 'BuildResidentialURBANoptModel', 'unit_type', unit_type)
            OpenStudio::Extension.set_measure_argument(osw, 'BuildResidentialURBANoptModel', 'cfa', cfa)
            OpenStudio::Extension.set_measure_argument(osw, 'BuildResidentialURBANoptModel', 'wall_height', wall_height)
            OpenStudio::Extension.set_measure_argument(osw, 'BuildResidentialURBANoptModel', 'num_units', num_units)
            OpenStudio::Extension.set_measure_argument(osw, 'BuildResidentialURBANoptModel', 'num_floors', num_floors)
            OpenStudio::Extension.set_measure_argument(osw, 'BuildResidentialURBANoptModel', 'foundation_type', foundation_type)
            OpenStudio::Extension.set_measure_argument(osw, 'BuildResidentialURBANoptModel', 'attic_type', attic_type)
            OpenStudio::Extension.set_measure_argument(osw, 'BuildResidentialURBANoptModel', 'num_bedrooms', num_bedrooms)
            OpenStudio::Extension.set_measure_argument(osw, 'BuildResidentialURBANoptModel', 'heating_system_type', heating_system_type)
            OpenStudio::Extension.set_measure_argument(osw, 'BuildResidentialURBANoptModel', 'heating_system_fuel', heating_system_fuel)
            OpenStudio::Extension.set_measure_argument(osw, 'BuildResidentialURBANoptModel', 'cooling_system_type', cooling_system_type)
            OpenStudio::Extension.set_measure_argument(osw, 'BuildResidentialURBANoptModel', 'heat_pump_type', heat_pump_type)

          elsif commercial_building_types.include? building_type

            # set_run_period
            timesteps_per_hour = 1
            begin
              timesteps_per_hour = feature.timesteps_per_hour
            rescue StandardError
            end
            begin_date = "2007-01-01"
            begin
              begin_date = feature.begin_date[0, 10]
            rescue StandardError
            end
            end_date = "2007-12-31"
            begin
              end_date = feature.end_date[0, 10]
            rescue StandardError
            end
            OpenStudio::Extension.set_measure_argument(osw, 'set_run_period', '__SKIP__', false)
            OpenStudio::Extension.set_measure_argument(osw, 'set_run_period', 'timesteps_per_hour', timesteps_per_hour)
            OpenStudio::Extension.set_measure_argument(osw, 'set_run_period', 'begin_date', begin_date)
            OpenStudio::Extension.set_measure_argument(osw, 'set_run_period', 'end_date', end_date)

            # convert to hash
            building_hash = feature.to_hash
            # check for detailed model filename
            OpenStudio::Extension.set_measure_argument(osw, 'PredictedMeanVote', '__SKIP__', false)
            if building_hash.key?(:detailed_model_filename)
              detailed_model_filename = building_hash[:detailed_model_filename]
              osw[:file_paths] << File.join(File.dirname(__FILE__), '../osm_building/')
              osw[:seed_file] = detailed_model_filename

              # skip PMV measure with detailed models:
              OpenStudio::Extension.set_measure_argument(osw, 'PredictedMeanVote', '__SKIP__', true)

            # in case detailed model filename is not present
            else

              building_type_1 = building_hash[:building_type]

              # lookup/map building type
              number_of_stories = building_hash[:number_of_stories]
              if building_hash.key?(:number_of_stories_above_ground)
                number_of_stories_above_ground = building_hash[:number_of_stories_above_ground]
                number_of_stories_below_ground = number_of_stories - number_of_stories_above_ground
              else
                number_of_stories_above_ground = number_of_stories
                number_of_stories_below_ground = 0
              end
              template = building_hash.key?(:template) ? building_hash[:template] : nil
              footprint_area = building_hash[:footprint_area]

              mapped_building_type_1 = lookup_building_type(building_type_1, template, footprint_area, number_of_stories)

              # process Mixed Use (for create_bar measure)
              if building_type_1 == 'Mixed use'
                # map mixed use types
                running_fraction = 0
                mixed_type_1 = building_hash[:mixed_type_1]
                mixed_type_2 = building_hash.key?(:mixed_type_2) ? building_hash[:mixed_type_2] : nil
                unless mixed_type_2.nil?
                  mixed_type_2_percentage = building_hash[:mixed_type_2_percentage]
                  mixed_type_2_fract_bldg_area = mixed_type_2_percentage * 0.01
                  running_fraction += mixed_type_2_fract_bldg_area
                end

                mixed_type_3 = building_hash.key?(:mixed_type_3) ? building_hash[:mixed_type_3] : nil
                unless mixed_type_3.nil?
                  mixed_type_3_percentage = building_hash[:mixed_type_3_percentage]
                  mixed_type_3_fract_bldg_area = mixed_type_3_percentage * 0.01
                  running_fraction += mixed_type_3_fract_bldg_area
                end

                mixed_type_4 = building_hash.key?(:mixed_type_4) ? building_hash[:mixed_type_4] : nil
                unless mixed_type_4.nil?
                  mixed_type_4_percentage = building_hash[:mixed_type_4_percentage]
                  mixed_type_4_fract_bldg_area = mixed_type_4_percentage * 0.01
                  running_fraction += mixed_type_4_fract_bldg_area
                end

                # potentially calculate from other inputs
                mixed_type_1_fract_bldg_area = building_hash.key?(:mixed_type_1_percentage) ? building_hash[:mixed_type_1_percentage] : (1 - running_fraction)

                # lookup mixed_use types
                footprint_1 = footprint_area * mixed_type_1_fract_bldg_area
                openstudio_mixed_type_1 = lookup_building_type(mixed_type_1, template, footprint_1, number_of_stories)
                unless mixed_type_2.nil?
                  footprint_2 = footprint_area * mixed_type_2_fract_bldg_area
                  openstudio_mixed_type_2 = lookup_building_type(mixed_type_2, template, footprint_2, number_of_stories)
                end
                unless mixed_type_3.nil?
                  footprint_3 = footprint_area * mixed_type_3_fract_bldg_area
                  openstudio_mixed_type_3 = lookup_building_type(mixed_type_3, template, footprint_3, number_of_stories)
                end
                unless mixed_type_4.nil?
                  footprint_4 = footprint_area * mixed_type_4_fract_bldg_area
                  openstudio_mixed_type_4 = lookup_building_type(mixed_type_4, template, footprint_4, number_of_stories)
                end
              end

              floor_height = 10
              if building_hash.key?(:system_type)
                system_type = building_hash[:system_type]
              else
                system_type = 'Inferred'
              end

              def time_mapping(time)
                hour = time.split(':')[0]
                minute = time.split(':')[1]
                fraction = minute.to_f/60
                fraction_roundup = fraction.round(2)
                minute_fraction = fraction_roundup.to_s.split('.')[1]
                new_time = [hour, minute_fraction].join('.')
                return new_time
              end

              # ChangeBuildingLocation
              # set skip measure to false change building location
              OpenStudio::Extension.set_measure_argument(osw, 'ChangeBuildingLocation', '__SKIP__', false)

              # cec climate zone takes precedence
              cec_found = false
              begin
                cec_climate_zone = feature.cec_climate_zone
                if !cec_climate_zone.empty?
                  cec_climate_zone = 'T24-CEC' + cec_climate_zone
                  OpenStudio::Extension.set_measure_argument(osw, 'ChangeBuildingLocation', 'climate_zone', cec_climate_zone)
                  cec_found = true
                end
              rescue StandardError
              end
              unless cec_found
                begin
                  climate_zone = feature.climate_zone
                  if !climate_zone.empty?
                    climate_zone = 'ASHRAE 169-2013-' + climate_zone
                    OpenStudio::Extension.set_measure_argument(osw, 'ChangeBuildingLocation', 'climate_zone', climate_zone)
                 end
                rescue StandardError
                end
              end

              # set weather file
              begin
                weather_filename = feature.weather_filename
                if !feature.weather_filename.nil? && !feature.weather_filename.empty?
                  OpenStudio::Extension.set_measure_argument(osw, 'ChangeBuildingLocation', 'weather_file_name', weather_filename)
                  puts "Setting weather_file_name to #{weather_filename} as specified in the FeatureFile"
                end
              rescue StandardError
                puts 'No weather_file specified on feature'
                epw_file_path = Dir.glob(File.join(File.dirname(__FILE__), '../weather/*.epw'))[0]
                if !epw_file_path.nil? && !epw_file_path.empty?
                  epw_file_name = File.basename(epw_file_path)
                  OpenStudio::Extension.set_measure_argument(osw, 'ChangeBuildingLocation', 'weather_file_name', epw_file_name)
                  puts "Setting weather_file_name to first epw file found in the weather folder: #{epw_file_name}"
                else
                  puts 'NO WEATHER FILES SPECIFIED...SIMULATIONS MAY FAIL'
                end
              end

              # set weekday start time
              begin
                weekday_start_time = feature.weekday_start_time
                if !feature.weekday_start_time.empty?
                  new_weekday_start_time = time_mapping(weekday_start_time)
                  OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'wkdy_op_hrs_start_time', new_weekday_start_time, 'create_typical_building_from_model 1')
                end
              rescue StandardError
              end

              # set weekday duration
              begin
                weekday_duration = feature.weekday_duration
                if !feature.weekday_duration.empty?
                  new_weekday_duration = time_mapping(weekday_duration)
                  OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'wkdy_op_hrs_duration', new_weekday_duration, 'create_typical_building_from_model 1')
                end
              rescue StandardError
              end
              
              # set weekend start time
              begin
                weekend_start_time = feature.weekend_start_time
                if !feature.weekend_start_time.empty?
                  new_weekend_start_time = time_mapping(weekend_start_time)
                  OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'wknd_op_hrs_start_time', new_weekend_start_time, 'create_typical_building_from_model 1')
                end
              rescue StandardError
              end
              
              # set weekend duration
              begin
                weekend_duration = feature.weekend_duration
                unless feature.weekend_duration.empty?
                  new_weekend_duration = time_mapping(weekend_duration)
                  OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'wknd_op_hrs_duration', new_weekend_duration, 'create_typical_building_from_model 1')
                end
              rescue StandardError
              end

              # template
              begin
                new_template = nil
                template = feature.template

                # can we override template with year_built info? (keeping same template family)
                if building_hash.key?(:year_built) && !building_hash[:year_built].nil? && !feature.template.empty?
                  new_template = lookup_template_by_year_built(template, year_built)
                elsif !feature.template.empty?
                  new_template = template
                end

                if new_template
                  OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'template', new_template)
                  OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'template', new_template, 'create_typical_building_from_model 1')
                  OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'template', new_template, 'create_typical_building_from_model 2')
                end
              rescue StandardError
              end
              
              # TODO: surface_elevation has no current mapping
              # TODO: tariff_filename has no current mapping
              
              # create a bar building, will have spaces tagged with individual space types given the
              # input building types
              # set skip measure to false
              OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', '__SKIP__', false)
              OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'single_floor_area', footprint_area)
              OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'floor_height', floor_height)
              OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'num_stories_above_grade', number_of_stories_above_ground)
              OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'num_stories_below_grade', number_of_stories_below_ground)

              OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_a', mapped_building_type_1)

              if building_type_1 == 'Mixed use'

                OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_a', openstudio_mixed_type_1)

                unless mixed_type_2.nil?
                  OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_b', openstudio_mixed_type_2)
                  OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_b_fract_bldg_area', mixed_type_2_fract_bldg_area)
                end
                unless mixed_type_3.nil?
                  OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_c', openstudio_mixed_type_3)
                  OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_c_fract_bldg_area', mixed_type_3_fract_bldg_area)
                end
                unless mixed_type_4.nil?
                  OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_d', openstudio_mixed_type_4)
                  OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_d_fract_bldg_area', mixed_type_4_fract_bldg_area)
                end
              end

              # calling create typical building the first time will create space types
              OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', '__SKIP__', false)
              OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'add_hvac', false, 'create_typical_building_from_model 1')

              # create a blended space type for each story
              OpenStudio::Extension.set_measure_argument(osw,
                                                         'blended_space_type_from_model', '__SKIP__', false)
              OpenStudio::Extension.set_measure_argument(osw,
                                                         'blended_space_type_from_model', 'blend_method', 'Building Story')

              # create geometry for the desired feature, this will reuse blended space types in the model for each story and remove the bar geometry
              OpenStudio::Extension.set_measure_argument(osw, 'urban_geometry_creation', '__SKIP__', false)
              OpenStudio::Extension.set_measure_argument(osw, 'urban_geometry_creation', 'geojson_file', scenario.feature_file.path)
              OpenStudio::Extension.set_measure_argument(osw, 'urban_geometry_creation', 'feature_id', feature_id)
              OpenStudio::Extension.set_measure_argument(osw, 'urban_geometry_creation', 'surrounding_buildings', 'ShadingOnly')
                            
              # call create typical building a second time, do not touch space types, only add hvac
              OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', '__SKIP__', false)
              OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'system_type', system_type, 'create_typical_building_from_model 2')
            end

          else
            raise "Building type #{building_type} not currently supported."
          end # building type == residential or commercial

        end # feature_type == 'Building'

        # call the default feature reporting measure
        OpenStudio::Extension.set_measure_argument(osw, 'default_feature_reports', 'feature_id', feature_id)
        OpenStudio::Extension.set_measure_argument(osw, 'default_feature_reports', 'feature_name', feature_name)
        OpenStudio::Extension.set_measure_argument(osw, 'default_feature_reports', 'feature_type', feature_type)

        return osw
      end # create_osw
    end # BaselineMapper
  end # Scenario
end # URBANopt
