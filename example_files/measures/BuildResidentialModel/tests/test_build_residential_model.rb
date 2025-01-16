# *********************************************************************************
# URBANopt (tm), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-example-geojson-project/blob/develop/LICENSE.md
# *********************************************************************************

# frozen_string_literal: true

require_relative '../../../resources/residential-measures/resources/hpxml-measures/HPXMLtoOpenStudio/resources/minitest_helper'
require_relative '../../../mappers/residential/util'
require_relative '../../../mappers/residential/template/util'
require_relative '../../../mappers/residential/samples/util'
require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require_relative '../measure.rb'
require 'csv'
require 'pathname'

class BuildResidentialModelTest < Minitest::Test
  def setup
    @tests_path = Pathname(__FILE__).dirname
    @run_path = @tests_path / 'run'
    FileUtils.mkdir_p(@run_path)
    @model_save = true # true helpful for debugging, i.e., save the HPXML files
  end

  def teardown
    FileUtils.rm_rf(@run_path) if !@model_save
  end

  def _initialize_arguments()
    @args = {}

    # BuildResidentialModel required arguments
    @args[:urbanopt_feature_id] = 1
    @args[:schedules_type] = 'stochastic'
    @args[:schedules_random_seed] = 1
    @args[:schedules_variation] = 'unit'
    @args[:geometry_num_floors_above_grade] = 1
    @args[:hpxml_path] = @hpxml_path.to_s
    @args[:output_dir] = File.dirname(@hpxml_path)

    # Optionals / Feature
    @args[:geometry_building_num_units] = 1
    @timestep = 60
    @run_period = 'Jan 1 - Dec 31'
    @calendar_year = 2007
    @weather_filename = 'USA_NY_Buffalo-Greater.Buffalo.Intl.AP.725280_TMY3.epw'
    @year_built = 2000
    @building_type = 'Single-Family Detached'
    @floor_area = 3055
    @number_of_bedrooms = 3
    @geometry_unit_orientation = nil
    @geometry_aspect_ratio = nil
    @occupancy_calculation_type = nil
    @number_of_occupants = nil
    @maximum_roof_height = 8.0
    @foundation_type = 'crawlspace - unvented'
    @attic_type = 'attic - vented'
    @roof_type = 'Gable'
    @onsite_parking_fraction = false
    @system_type = 'Residential - furnace and central air conditioner'
    @heating_system_fuel_type = 'natural gas'
  end

  def test_hpxml_dir
    # in https://github.com/urbanopt/urbanopt-geojson-gem/blob/develop/lib/urbanopt/geojson/schema/building_properties.json, see:
    # - "hpxml_directory"

    test_folder = @run_path / __method__.to_s

    @hpxml_path = test_folder / '' / 'feature.xml'
    _initialize_arguments()
    @args[:hpxml_dir] = '18'
    _test_measure(expected_errors: ["HPXML directory 'xml_building/18' was specified for feature ID = 1, but could not be found."])

    @hpxml_path = test_folder / '' / 'feature.xml'
    _initialize_arguments()
    @args[:hpxml_dir] = '../measures/BuildResidentialModel/tests/xml_building/17'
    _test_measure(expected_errors: ["HPXML directory 'xml_building/17' must contain exactly 1 HPXML file; the single file can describe multiple dwelling units of a feature."])

    @hpxml_path = test_folder / '' / 'feature.xml'
    _initialize_arguments()
    @args[:hpxml_dir] = '17'
    _test_measure(expected_errors: ['The number of actual dwelling units (4) differs from the specified number of units (1).'])

    @hpxml_path = test_folder / '17' / 'feature.xml'
    FileUtils.mkdir_p(File.dirname(@hpxml_path))
    _initialize_arguments()
    @args[:hpxml_dir] = '17'
    @args[:geometry_building_num_units] = 4
    _test_measure()
  end

  def test_schedules_type
    # Baseline.rb mapper currently hardcodes schedules_type to "stochastic"

    schedules_types = ['stochastic', 'smooth']

    test_folder = @run_path / __method__.to_s
    schedules_types.each do |schedules_type|
      @hpxml_path = test_folder / "#{schedules_type}" / 'feature.xml'
      _initialize_arguments()

      @args[:schedules_type] = schedules_type

      _apply_residential()
      _test_measure()
    end
  end

  def test_feature_building_types_num_units_and_stories
    # in https://github.com/urbanopt/urbanopt-geojson-gem/blob/develop/lib/urbanopt/geojson/schema/building_properties.json, see:
    # - "buildingType"
    # - "number_of_residential_units"
    # - "number_of_stories_above_ground"

    feature_building_types = ['Single-Family Detached', 'Single-Family Attached', 'Multifamily']
    feature_number_of_residential_unitss = (1..3).to_a
    feature_number_of_stories_above_grounds = (1..2).to_a

    test_folder = @run_path / __method__.to_s
    feature_building_types.each do |feature_building_type|
      feature_number_of_residential_unitss.each do |feature_number_of_residential_units|
        feature_number_of_stories_above_grounds.each do |feature_number_of_stories_above_ground|
          @hpxml_path = test_folder / "#{feature_building_type}_#{feature_number_of_residential_units}_#{feature_number_of_stories_above_ground}" / 'feature.xml'
          _initialize_arguments()

          @building_type = feature_building_type
          @args[:geometry_num_floors_above_grade] = feature_number_of_stories_above_ground
          @args[:geometry_building_num_units] = feature_number_of_residential_units

          _apply_residential()
          _test_measure(expected_errors: [])
        end
      end
    end
  end

  def test_feature_building_foundation_and_attic_types_and_num_stories
    # in https://github.com/urbanopt/urbanopt-geojson-gem/blob/develop/lib/urbanopt/geojson/schema/building_properties.json, see:
    # - "buildingType"
    # - "foundationType"
    # - "atticType"
    # - "number_of_stories_above_ground"

    feature_building_types = ['Single-Family Detached', 'Single-Family Attached', 'Multifamily']
    feature_foundation_types = ['slab', 'crawlspace - vented', 'crawlspace - conditioned', 'basement - unconditioned',	'basement - conditioned', 'ambient']
    feature_attic_types = ['attic - vented', 'attic - conditioned', 'flat roof']
    feature_number_of_stories_above_grounds = (1..2).to_a

    test_folder = @run_path / __method__.to_s
    feature_building_types.each do |feature_building_type|
      feature_foundation_types.each do |feature_foundation_type|
        feature_attic_types.each do |feature_attic_type|
          feature_number_of_stories_above_grounds.each do |feature_number_of_stories_above_ground|
            @hpxml_path = test_folder / "#{feature_building_type}_#{feature_foundation_type}_#{feature_attic_type}_#{feature_number_of_stories_above_ground}" / 'feature.xml'
            _initialize_arguments()

            @building_type = feature_building_type
            @foundation_type = feature_foundation_type
            @attic_type = feature_attic_type
            @args[:geometry_num_floors_above_grade] = feature_number_of_stories_above_ground

            expected_errors = []
            if feature_attic_type == 'attic - conditioned' && feature_number_of_stories_above_ground == 1
              expected_errors += ['Units with a conditioned attic must have at least two above-grade floors.']
            end
            if feature_building_type == 'Multifamily' && ['basement - conditioned', 'crawlspace - conditioned'].include?(feature_foundation_type)
              expected_errors += ['Conditioned basement/crawlspace foundation type for apartment units is not currently supported.']
            end

            _apply_residential()
            _test_measure(expected_errors: expected_errors)
          end
        end
      end
    end
  end

  def test_feature_building_types_num_units_and_bedrooms
    # in https://github.com/urbanopt/urbanopt-geojson-gem/blob/develop/lib/urbanopt/geojson/schema/building_properties.json, see:
    # - "buildingType"
    # - "number_of_residential_units"
    # - "number_of_bedrooms"

    feature_building_types = ['Single-Family Detached', 'Multifamily']
    feature_number_of_residential_unitss = (2..4).to_a
    feature_number_of_bedroomss = (11..13).to_a

    test_folder = @run_path / __method__.to_s
    feature_building_types.each do |feature_building_type|
      feature_number_of_residential_unitss.each do |feature_number_of_residential_units|
        feature_number_of_bedroomss.each do |feature_number_of_bedrooms|
          @hpxml_path = test_folder / "#{feature_building_type}_#{feature_number_of_residential_units}_#{feature_number_of_bedrooms}" / 'feature.xml'
          _initialize_arguments()

          @building_type = feature_building_type
          @args[:geometry_building_num_units] = feature_number_of_residential_units
          @number_of_bedrooms = feature_number_of_bedrooms

          _apply_residential()
          _test_measure()
        end
      end
    end
  end

  def test_feature_building_occ_calc_types_num_occupants_and_units
    # in https://github.com/urbanopt/urbanopt-geojson-gem/blob/develop/lib/urbanopt/geojson/schema/building_properties.json, see:
    # - "buildingType"
    # - "occupancy_calculation_type"
    # - "number_of_residential_units"
    # - "number_of_occupants"

    feature_building_types = ['Single-Family Detached', 'Multifamily']
    feature_occupancy_calculation_types = ['asset', 'operational']
    feature_number_of_residential_unitss = (2..3).to_a
    feature_number_of_occupantss = [nil, 3]

    test_folder = @run_path / __method__.to_s
    feature_building_types.each do |feature_building_type|
      feature_occupancy_calculation_types.each do |feature_occupancy_calculation_type|
        feature_number_of_residential_unitss.each do |feature_number_of_residential_units|
          feature_number_of_occupantss.each do |feature_number_of_occupants|
            @hpxml_path = test_folder / "#{feature_building_type}_#{feature_occupancy_calculation_type}_#{feature_number_of_residential_units}_#{feature_number_of_occupants}" / 'feature.xml'
            _initialize_arguments()

            @building_type = feature_building_type
            @occupancy_calculation_type = feature_occupancy_calculation_type
            @args[:geometry_building_num_units] = feature_number_of_residential_units
            @number_of_occupants = feature_number_of_occupants

            _apply_residential()
            _test_measure()
          end
        end
      end
    end
  end

  def test_feature_building_foundation_types_and_garages
    # in https://github.com/urbanopt/urbanopt-geojson-gem/blob/develop/lib/urbanopt/geojson/schema/building_properties.json, see:
    # - "buildingType"
    # - "foundationType"
    # - "onsite_parking_fraction"

    feature_building_types = ['Single-Family Detached', 'Single-Family Attached', 'Multifamily']
    feature_foundation_types = ['slab', 'crawlspace - vented', 'crawlspace - conditioned', 'basement - unconditioned',	'basement - conditioned', 'ambient']
    feature_onsite_parking_fractions = [false, true]

    test_folder = @run_path / __method__.to_s
    feature_building_types.each do |feature_building_type|
      feature_foundation_types.each do |feature_foundation_type|
        feature_onsite_parking_fractions.each do |feature_onsite_parking_fraction|
          @hpxml_path = test_folder / "#{feature_building_type}_#{feature_foundation_type}_#{feature_onsite_parking_fraction}" / 'feature.xml'
          _initialize_arguments()

          @building_type = feature_building_type
          @foundation_type = feature_foundation_type
          @onsite_parking_fraction = feature_onsite_parking_fraction
          @args[:geometry_building_num_units] = 2

          expected_errors = []
          if feature_foundation_type == 'ambient' && feature_onsite_parking_fraction
            expected_errors += ['Cannot handle garages with an ambient foundation type.']
          end
          if feature_building_type == 'Multifamily' && ['basement - conditioned', 'crawlspace - conditioned'].include?(feature_foundation_type)
            expected_errors += ['Conditioned basement/crawlspace foundation type for apartment units is not currently supported.']
          end

          _apply_residential()
          _test_measure(expected_errors: expected_errors)
        end
      end
    end
  end

  def test_hvac_system_and_fuel_types
    # in https://github.com/urbanopt/urbanopt-geojson-gem/blob/develop/lib/urbanopt/geojson/schema/building_properties.json, see:
    # - "systemType" (those prefixed with "Residential")
    # - "heatingSystemFuelType"

    feature_system_types = ['Residential - electric resistance and no cooling', 'Residential - electric resistance and central air conditioner',	'Residential - electric resistance and room air conditioner', 'Residential - electric resistance and evaporative cooler', 'Residential - furnace and no cooling', 'Residential - furnace and central air conditioner', 'Residential - furnace and room air conditioner', 'Residential - furnace and evaporative cooler', 'Residential - boiler and no cooling', 'Residential - boiler and central air conditioner', 'Residential - boiler and room air conditioner', 'Residential - boiler and evaporative cooler', 'Residential - air-to-air heat pump', 'Residential - mini-split heat pump', 'Residential - ground-to-air heat pump']
    feature_heating_system_fuel_types = ['electricity', 'natural gas', 'fuel oil', 'propane', 'wood']

    test_folder = @run_path / __method__.to_s
    feature_system_types.each do |feature_system_type|
      feature_heating_system_fuel_types.each do |feature_heating_system_fuel_type|
        @hpxml_path = test_folder / "#{feature_system_type}_#{feature_heating_system_fuel_type}" / 'feature.xml'
        _initialize_arguments()

        @system_type = feature_system_type
        @heating_system_fuel_type = feature_heating_system_fuel_type

        _apply_residential()
        _test_measure()
      end
    end
  end

  def test_residential_templates
    # in https://github.com/urbanopt/urbanopt-geojson-gem/blob/develop/lib/urbanopt/geojson/schema/building_properties.json, see:
    # - "templateType"

    feature_templates = ['Residential IECC 2006 - Customizable Template Sep 2020', 'Residential IECC 2009 - Customizable Template Sep 2020', 'Residential IECC 2012 - Customizable Template Sep 2020', 'Residential IECC 2015 - Customizable Template Sep 2020', 'Residential IECC 2018 - Customizable Template Sep 2020', 'Residential IECC 2006 - Customizable Template Apr 2022', 'Residential IECC 2009 - Customizable Template Apr 2022', 'Residential IECC 2012 - Customizable Template Apr 2022', 'Residential IECC 2015 - Customizable Template Apr 2022', 'Residential IECC 2018 - Customizable Template Apr 2022']
    climate_zones = ['1B', '5A']

    test_folder = @run_path / __method__.to_s
    feature_templates.each do |feature_template|
      climate_zones.each do |climate_zone|
        @hpxml_path = test_folder / "#{feature_template}_#{climate_zone}" / 'feature.xml'
        _initialize_arguments()

        @template = feature_template
        @climate_zone = climate_zone

        _apply_residential()
        _apply_residential_template()
        _test_measure()
      end
    end
  end

  def test_residential_samples
    # in https://github.com/urbanopt/urbanopt-geojson-gem/blob/develop/lib/urbanopt/geojson/schema/building_properties.json, see:
    # - "buildingType"
    # - "number_of_residential_units"
    # - "floor_area"
    # - "number_of_bedrooms"
    # - "characterize_residential_buildings_from_buildstock_csv"
    # - "resstock_buildstock_csv_path"

    FileUtils.mkdir_p(File.join(File.dirname(__FILE__), '../../../run')) # for resstock_buildstock_csv_match_log.csv

    @buildstock_csv_path = File.absolute_path(File.join(File.dirname(__FILE__), '../../../resources/residential-measures/test/base_results/baseline/annual/buildstock.csv'))

    feature_building_types = ['Single-Family Detached', 'Multifamily']
    feature_number_of_residential_unitss = [1, 5]
    feature_floor_areas = [5000]

    test_folder = @run_path / __method__.to_s
    feature_building_types.each do |feature_building_type|
      feature_number_of_residential_unitss.each do |feature_number_of_residential_units|
        feature_floor_areas.each do |feature_floor_area|
          @hpxml_path = test_folder / "#{feature_building_type}_#{feature_number_of_residential_units}_#{feature_floor_area}" / 'feature.xml'
          _initialize_arguments()

          @building_type = feature_building_type
          @args[:geometry_building_num_units] = feature_number_of_residential_units
          @floor_area = feature_floor_area
          @number_of_bedrooms = 3 * @args[:geometry_building_num_units]
          @number_of_stories_above_ground = nil # not specified in geojson

          if @building_type == 'Multifamily'
            @number_of_bedrooms = 2 * @args[:geometry_building_num_units]
            @foundation_type = 'slab'
            @attic_type = 'flat roof'
          end

          # Skip
          next if @building_type == 'Single-Family Detached' && @args[:geometry_building_num_units] > 1

          expected_errors = []
          if ['Multifamily'].include?(@building_type) && @args[:geometry_building_num_units] == 1
            expected_errors = ['Feature ID = 1: No matching buildstock building ID found.']
          end

          _apply_residential()

          # Don't try to match these because the sample buildstock.csv is too small to be that precise
          @year_built = nil
          @system_type = nil
          @heating_system_fuel_type = nil

          resstock_building_id = _apply_residential_samples()
          _test_measure(expected_errors: expected_errors)

          next if !expected_errors.empty?

          urbanopt_path = @hpxml_path
          resstock_path = File.absolute_path(File.join(File.dirname(__FILE__), 'samples/precomputed/run1/run/home.xml'))
          _check_against_resstock('buildstock_csv_path.yml', resstock_building_id, @args[:geometry_building_num_units], urbanopt_path, resstock_path)
        end
      end
    end
  end

  def test_residential_samples2
    # in https://github.com/urbanopt/urbanopt-geojson-gem/blob/develop/lib/urbanopt/geojson/schema/building_properties.json, see:
    # - "buildingType"
    # - "number_of_residential_units"
    # - "number_of_stories_above_ground"
    # - "year_built"
    # - "number_of_bedrooms"
    # - "characterize_residential_buildings_from_buildstock_csv"
    # - "resstock_buildstock_csv_path"

    FileUtils.mkdir_p(File.join(File.dirname(__FILE__), '../../../run')) # for resstock_buildstock_csv_match_log.csv

    @buildstock_csv_path = File.absolute_path(File.join(File.dirname(__FILE__), '../../../resources/residential-measures/test/base_results/baseline/annual/buildstock.csv'))

    feature_number_of_stories_above_grounds = [2]
    feature_year_builts = [1963]
    feature_number_of_bedroomss = [32]

    test_folder = @run_path / __method__.to_s
    feature_number_of_stories_above_grounds.each do |feature_number_of_stories_above_ground|
      feature_year_builts.each do |feature_year_built|
        feature_number_of_bedroomss.each do |feature_number_of_bedrooms|
          @hpxml_path = test_folder / "#{feature_number_of_stories_above_ground}_#{feature_year_built}_#{feature_number_of_bedrooms}" / 'feature.xml'
          _initialize_arguments()

          @building_type = 'Multifamily'
          @args[:geometry_building_num_units] = 16
          @floor_area = 800 * @args[:geometry_building_num_units]
          @number_of_stories_above_ground = feature_number_of_stories_above_ground
          @year_built = feature_year_built
          @number_of_bedrooms = feature_number_of_bedrooms
          @foundation_type = 'slab'
          @attic_type = 'flat roof'

          _apply_residential()

          @system_type = nil
          @heating_system_fuel_type = nil

          resstock_building_id = _apply_residential_samples()
          _test_measure(expected_errors: [])

          urbanopt_path = @hpxml_path
          resstock_path = File.absolute_path(File.join(File.dirname(__FILE__), 'samples/precomputed/run1/run/home.xml'))
          _check_against_resstock('buildstock_csv_path.yml', resstock_building_id, @args[:geometry_building_num_units], urbanopt_path, resstock_path)
        end
      end
    end
  end

  def test_residential_samples3
    # in https://github.com/urbanopt/urbanopt-geojson-gem/blob/develop/lib/urbanopt/geojson/schema/building_properties.json, see:
    # - "characterize_residential_buildings_from_buildstock_csv"
    # - "uo_buildstock_mapping_csv_path"

    FileUtils.mkdir_p(File.join(File.dirname(__FILE__), '../../../run')) # for resstock_buildstock_csv_match_log.csv

    @uo_buildstock_mapping_csv_path = File.absolute_path(File.join(File.dirname(__FILE__), '../../../resources/uo_buildstock_mapping.csv'))

    feature_ids = ['14', '15', '16']

    test_folder = @run_path / __method__.to_s
    feature_ids.each do |feature_id|
      @hpxml_path = test_folder / "#{feature_id}" / 'feature.xml'
      _initialize_arguments()

      _apply_residential()
      resstock_building_id = find_building_for_uo_id(@uo_buildstock_mapping_csv_path, feature_id)

      residential_samples(@args, resstock_building_id, @uo_buildstock_mapping_csv_path)

      _test_measure(expected_errors: [])

      @heating_system_fuel_type = nil
      @year_built = nil

      urbanopt_path = @hpxml_path
      resstock_path = File.absolute_path(File.join(File.dirname(__FILE__), 'samples/precomputed/run1/run/home.xml'))
      _check_against_resstock('uo_buildstock_mapping_csv_path.yml', resstock_building_id, @args[:geometry_building_num_units], urbanopt_path, resstock_path)
    end
  end

  def test_multifamily_one_unit_per_floor
    feature_building_types = ['Multifamily']
    feature_number_of_residential_unitss = (1..5).to_a

    test_folder = @run_path / __method__.to_s
    feature_building_types.each do |feature_building_type|
      feature_number_of_residential_unitss.each do |feature_number_of_residential_units|
        @hpxml_path = test_folder / "#{feature_building_type}_#{feature_number_of_residential_units}" / 'feature.xml'
        _initialize_arguments()

        @building_type = feature_building_type
        @args[:geometry_building_num_units] = feature_number_of_residential_units
        @args[:geometry_num_floors_above_grade] = feature_number_of_residential_units
        @number_of_bedrooms *= feature_number_of_residential_units
        @maximum_roof_height *= @args[:geometry_num_floors_above_grade]

        _apply_residential()
        _test_measure()
      end
    end
  end

  private

  def _apply_residential()
    residential_simulation(@args, @timestep, @run_period, @calendar_year, @weather_filename, @year_built)
    residential_geometry_unit(@args, @building_type, @floor_area, @number_of_bedrooms, @geometry_unit_orientation, @geometry_unit_aspect_ratio, @occupancy_calculation_type, @number_of_occupants, @maximum_roof_height)
    residential_geometry_foundation(@args, @foundation_type)
    residential_geometry_attic(@args, @attic_type, @roof_type)
    residential_geometry_garage(@args, @onsite_parking_fraction)
    residential_geometry_neighbor(@args)
    residential_hvac(@args, @system_type, @heating_system_fuel_type)
    residential_appliances(@args)
  end

  def _apply_residential_template()
    residential_template(@args, @template, @climate_zone)
  end

  def _apply_residential_samples()
    mapped_properties = {}
    mapped_properties['Geometry Building Type RECS'] = map_to_resstock_building_type(@building_type, @args[:geometry_building_num_units])
    mapped_properties['Geometry Stories'] = [@number_of_stories_above_ground] if !@number_of_stories_above_ground.nil?
    mapped_properties['Geometry Building Number Units SFA'], mapped_properties['Geometry Building Number Units MF'] = map_to_resstock_num_units(@building_type, @args[:geometry_building_num_units])
    mapped_properties['Geometry Floor Area'] = map_to_resstock_floor_area(@floor_area, @args[:geometry_building_num_units]) if !@floor_area.nil?
    mapped_properties['Bedrooms'] = [@number_of_bedrooms / @args[:geometry_building_num_units]] if !@number_of_bedrooms.nil?
    mapped_properties['Geometry Foundation Type'] = map_to_resstock_foundation_type(@foundation_type) if !@foundation_type.nil?
    mapped_properties['Geometry Attic Type'] = map_to_resstock_attic_type(@attic_type) if !@attic_type.nil?
    mapped_properties['Vintage ACS'] = map_to_resstock_vintage(@year_built) if !@year_built.nil?
    mapped_properties['HVAC Heating Efficiency'], mapped_properties['HVAC Cooling Efficiency'] = map_to_resstock_system_type(@system_type, @heating_system_fuel_type) if !@system_type.nil?
    mapped_properties['Heating Fuel'] = map_to_resstock_heating_fuel(@heating_system_fuel_type) if !@heating_system_fuel_type.nil?
    mapped_properties['Occupants'] = map_to_resstock_num_occupants(@number_of_occupants, @args[:geometry_building_num_units]) if !@number_of_occupants.nil?

    resstock_building_id, infos = get_selected_id(mapped_properties, @buildstock_csv_path, @args[:urbanopt_feature_id])
    residential_samples(@args, resstock_building_id, @buildstock_csv_path)
    return resstock_building_id
  end

  def _test_measure(expected_errors: [])
    # create an instance of the measure
    measure = BuildResidentialModel.new

    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
    model = OpenStudio::Model::Model.new

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if @args.has_key?(arg.name.to_sym)
        assert(temp_arg_var.setValue(@args[arg.name.to_sym]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    puts "\n#{@hpxml_path}"
    measure.run(model, runner, argument_map)
    result = runner.result

    # assert that it ran correctly
    if !expected_errors.empty?
      show_output(result) unless result.value.valueName == 'Fail'
      assert_equal('Fail', result.value.valueName)

      error_msgs = result.errors.map { |x| x.logMessage }
      expected_errors.each do |expected_error|
        assert_includes(error_msgs, expected_error)
      end
      assert(!File.exist?(@hpxml_path))
    else
      show_output(result) unless result.value.valueName == 'Success'
      assert_equal('Success', result.value.valueName)
      assert(File.exist?(@hpxml_path))
    end
  end

  def _check_against_resstock(yml_file, resstock_building_id, number_of_residential_units, urbanopt_path, resstock_path)
    # Check URBANopt HPXML file against ResStock HPXML file for the Building ID that was selected

    cli_path = OpenStudio.getOpenStudioCLI
    run_analysis_path = File.absolute_path(File.join(File.dirname(__FILE__), '../../../resources/residential-measures/workflow/run_analysis.rb'))
    yml_path = File.absolute_path(File.join(File.dirname(__FILE__), "samples/#{yml_file}"))

    command = "\"#{cli_path}\" #{run_analysis_path} -y #{yml_path} -o -m -i #{resstock_building_id}"
    puts command
    system(command, [:out, :err] => File::NULL)

    hpxml_urbanopt = HPXML.new(hpxml_path: urbanopt_path, building_id: 'ALL')
    hpxml_resstock = HPXML.new(hpxml_path: resstock_path, building_id: 'ALL')

    assert_equal(number_of_residential_units, hpxml_urbanopt.buildings.size)
    assert_equal(1, hpxml_resstock.buildings.size)

    assert(hpxml_resstock.header.to_s != hpxml_urbanopt.header.to_s)

    res_bldg = hpxml_resstock.buildings[0]
    uo_bldg = hpxml_urbanopt.buildings[0] # assume all units are identical except for stochastic schedules

    assert(res_bldg.state_code != uo_bldg.state_code)
    assert(res_bldg.zip_code != uo_bldg.zip_code)
    assert(res_bldg.dst_enabled == uo_bldg.dst_enabled)
    assert(res_bldg.dst_begin_month == uo_bldg.dst_begin_month)
    assert(res_bldg.dst_begin_day == uo_bldg.dst_begin_day)
    assert(res_bldg.dst_end_month == uo_bldg.dst_end_month)
    assert(res_bldg.dst_end_day == uo_bldg.dst_end_day)
    assert(res_bldg.site.to_s == uo_bldg.site.to_s)
    assert(res_bldg.neighbor_buildings.to_s == uo_bldg.neighbor_buildings.to_s)
    assert(res_bldg.building_occupancy.to_s == uo_bldg.building_occupancy.to_s)
    res_bldg.building_construction.conditioned_floor_area = nil
    uo_bldg.building_construction.conditioned_floor_area = nil
    res_bldg.building_construction.conditioned_building_volume = nil
    uo_bldg.building_construction.conditioned_building_volume = nil
    assert(res_bldg.building_construction.to_s == res_bldg.building_construction.to_s)
    assert(res_bldg.header.to_s != uo_bldg.header.to_s)
    assert(res_bldg.climate_and_risk_zones.to_s != uo_bldg.climate_and_risk_zones.to_s)
    res_bldg.climate_and_risk_zones.climate_zone_ieccs.zip(uo_bldg.climate_and_risk_zones.climate_zone_ieccs).each do |res, uo|
      res.zone = nil
      uo.zone = nil
      assert(res.to_s == uo.to_s)
    end
    res_bldg.air_infiltration_measurements.zip(uo_bldg.air_infiltration_measurements).each do |res, uo|
      res.infiltration_volume = nil
      uo.infiltration_volume = nil
      res.a_ext = nil
      uo.a_ext = nil
      assert(res.to_s == uo.to_s)
    end
    assert(res_bldg.air_infiltration.to_s == uo_bldg.air_infiltration.to_s)
    res_bldg.attics.zip(uo_bldg.attics).each do |res, uo|
      assert(res.to_s == uo.to_s)
    end
    res_bldg.foundations.zip(uo_bldg.foundations).each do |res, uo|
      assert(res.to_s == uo.to_s)
    end
    res_bldg.roofs.zip(uo_bldg.roofs).each do |res, uo|
      res.area = nil
      uo.area = nil
      assert(res.to_s == uo.to_s)
    end
    res_bldg.rim_joists.zip(uo_bldg.rim_joists).each do |res, uo|
      res.area = nil
      uo.area = nil
      assert(res.to_s == uo.to_s)
    end
    res_bldg.walls.zip(uo_bldg.walls).each do |res, uo|
      res.area = nil
      uo.area = nil
      assert(res.to_s == uo.to_s)
    end
    res_bldg.foundation_walls.zip(uo_bldg.foundation_walls).each do |res, uo|
      res.area = nil
      uo.area = nil
      assert(res.to_s == uo.to_s)
    end
    res_bldg.floors.zip(uo_bldg.floors).each do |res, uo|
      res.area = nil
      uo.area = nil
      assert(res.to_s == uo.to_s)
    end
    res_bldg.slabs.zip(uo_bldg.slabs).each do |res, uo|
      res.area = nil
      uo.area = nil
      res.exposed_perimeter = nil
      uo.exposed_perimeter = nil
      assert(res.to_s == uo.to_s)
    end
    res_bldg.windows.zip(uo_bldg.windows).each do |res, uo|
      next if res.nil? || uo.nil?

      res.area = nil
      uo.area = nil
      res.azimuth = nil
      uo.azimuth = nil
      res.orientation = nil
      uo.orientation = nil
      res.overhangs_distance_to_top_of_window = nil
      uo.overhangs_distance_to_top_of_window = nil
      res.overhangs_distance_to_bottom_of_window = nil
      uo.overhangs_distance_to_bottom_of_window = nil
      res.attached_to_wall_idref = nil
      uo.attached_to_wall_idref = nil
      assert(res.to_s == uo.to_s)
    end
    res_bldg.doors.zip(uo_bldg.doors).each do |res, uo|
      assert(res.to_s == uo.to_s)
    end
    assert(res_bldg.partition_wall_mass.to_s == uo_bldg.partition_wall_mass.to_s)
    assert(res_bldg.furniture_mass.to_s == uo_bldg.furniture_mass.to_s)
    res_bldg.heating_systems.zip(uo_bldg.heating_systems).each do |res, uo|
      res.heating_capacity = nil
      uo.heating_capacity = nil
      res.heating_airflow_cfm = nil
      uo.heating_airflow_cfm = nil
      assert(res.to_s == uo.to_s)
    end
    res_bldg.cooling_systems.zip(uo_bldg.cooling_systems).each do |res, uo|
      res.cooling_capacity = nil
      uo.cooling_capacity = nil
      res.cooling_airflow_cfm = nil
      uo.cooling_airflow_cfm = nil
      assert(res.to_s == uo.to_s)
    end
    res_bldg.heat_pumps.zip(uo_bldg.heat_pumps).each do |res, uo|
      res.heating_capacity = nil
      uo.heating_capacity = nil
      res.heating_airflow_cfm = nil
      uo.heating_airflow_cfm = nil
      res.cooling_capacity = nil
      uo.cooling_capacity = nil
      res.cooling_airflow_cfm = nil
      uo.cooling_airflow_cfm = nil
      res.backup_heating_capacity = nil
      uo.backup_heating_capacity = nil
      assert(res.to_s == uo.to_s)
    end
    res_bldg.hvac_controls.zip(uo_bldg.hvac_controls).each do |res, uo|
      # Different weather files have different heat/cool seasons
      res.seasons_heating_begin_month = nil
      uo.seasons_heating_begin_month = nil
      res.seasons_heating_end_month = nil
      uo.seasons_heating_end_month = nil
      res.seasons_heating_end_day = nil
      uo.seasons_heating_end_day = nil
      res.seasons_cooling_begin_month = nil
      uo.seasons_cooling_begin_month = nil
      res.seasons_cooling_end_month = nil
      uo.seasons_cooling_end_month = nil
      res.seasons_cooling_end_day = nil
      uo.seasons_cooling_end_day = nil
      assert(res.to_s == uo.to_s)
    end
    res_bldg.hvac_distributions.zip(uo_bldg.hvac_distributions).each do |res, uo|
      res.conditioned_floor_area_served = nil
      uo.conditioned_floor_area_served = nil
      assert(res.to_s == uo.to_s)
      res.duct_leakage_measurements.zip(uo.duct_leakage_measurements).each do |res2, uo2|
        assert(res2.to_s == uo2.to_s)
      end
      res.ducts.zip(uo.ducts).each do |res2, uo2|
        res2.duct_surface_area = nil
        uo2.duct_surface_area = nil
        assert(res2.to_s == uo2.to_s)
      end
    end
    res_bldg.ventilation_fans.zip(uo_bldg.ventilation_fans).each do |res, uo|
      assert(res.to_s == uo.to_s)
    end
    res_bldg.water_heating_systems.zip(uo_bldg.water_heating_systems).each do |res, uo|
      assert(res.to_s == uo.to_s)
    end
    res_bldg.hot_water_distributions.zip(uo_bldg.hot_water_distributions).each do |res, uo|
      res.standard_piping_length = nil
      uo.standard_piping_length = nil
      assert(res.to_s == uo.to_s)
    end
    res_bldg.water_fixtures.zip(uo_bldg.water_fixtures).each do |res, uo|
      assert(res.to_s == uo.to_s)
    end
    assert(res_bldg.water_heating.to_s == uo_bldg.water_heating.to_s)
    res_bldg.solar_thermal_systems.zip(uo_bldg.solar_thermal_systems).each do |res, uo|
      assert(res.to_s == uo.to_s)
    end
    res_bldg.pv_systems.zip(uo_bldg.pv_systems).each do |res, uo|
      assert(res.to_s == uo.to_s)
    end
    res_bldg.inverters.zip(uo_bldg.inverters).each do |res, uo|
      assert(res.to_s == uo.to_s)
    end
    res_bldg.batteries.zip(uo_bldg.batteries).each do |res, uo|
      assert(res.to_s == uo.to_s)
    end
    res_bldg.generators.zip(uo_bldg.generators).each do |res, uo|
      assert(res.to_s == uo.to_s)
    end
    res_bldg.clothes_washers.zip(uo_bldg.clothes_washers).each do |res, uo|
      assert(res.to_s == uo.to_s)
    end
    res_bldg.clothes_dryers.zip(uo_bldg.clothes_dryers).each do |res, uo|
      assert(res.to_s == uo.to_s)
    end
    res_bldg.dishwashers.zip(uo_bldg.dishwashers).each do |res, uo|
      assert(res.to_s == uo.to_s)
    end
    res_bldg.refrigerators.zip(uo_bldg.refrigerators).each do |res, uo|
      assert(res.to_s == uo.to_s)
    end
    res_bldg.freezers.zip(uo_bldg.freezers).each do |res, uo|
      assert(res.to_s == uo.to_s)
    end
    res_bldg.dehumidifiers.zip(uo_bldg.dehumidifiers).each do |res, uo|
      assert(res.to_s == uo.to_s)
    end
    res_bldg.cooking_ranges.zip(uo_bldg.cooking_ranges).each do |res, uo|
      assert(res.to_s == uo.to_s)
    end
    res_bldg.ovens.zip(uo_bldg.ovens).each do |res, uo|
      assert(res.to_s == uo.to_s)
    end
    res_bldg.lighting_groups.zip(uo_bldg.lighting_groups).each do |res, uo|
      assert(res.to_s == uo.to_s)
    end
    res_bldg.ceiling_fans.zip(uo_bldg.ceiling_fans).each do |res, uo|
      res.monthly_multipliers = nil
      uo.monthly_multipliers = nil
      assert(res.to_s == uo.to_s)
    end
    assert(res_bldg.lighting.to_s == uo_bldg.lighting.to_s)
    res_bldg.pools.zip(uo_bldg.pools).each do |res, uo|
      res.pump_kwh_per_year = nil
      uo.pump_kwh_per_year = nil
      res.heater_load_value = nil
      uo.heater_load_value = nil
      assert(res.to_s == uo.to_s)
    end
    res_bldg.permanent_spas.zip(uo_bldg.permanent_spas).each do |res, uo|
      res.pump_kwh_per_year = nil
      uo.pump_kwh_per_year = nil
      res.heater_load_value = nil
      uo.heater_load_value = nil
      assert(res.to_s == uo.to_s)
    end
    res_bldg.portable_spas.zip(uo_bldg.portable_spas).each do |res, uo|
      assert(res.to_s == uo.to_s)
    end
    res_bldg.plug_loads.zip(uo_bldg.plug_loads).each do |res, uo|
      res.kwh_per_year = nil
      uo.kwh_per_year = nil
      assert(res.to_s == uo.to_s)
    end
    res_bldg.fuel_loads.zip(uo_bldg.fuel_loads).each do |res, uo|
      res.therm_per_year = nil
      uo.therm_per_year = nil
      assert(res.to_s == uo.to_s)
    end
  end
end
