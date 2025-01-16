# *********************************************************************************
# URBANopt (tm), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-example-geojson-project/blob/develop/LICENSE.md
# *********************************************************************************

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

require 'openstudio'
resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../../resources'))
require File.join(resources_path, 'residential-measures/resources/buildstock')
require File.join(resources_path, 'residential-measures/resources/hpxml-measures/HPXMLtoOpenStudio/resources/meta_measure')

# start the measure
class BuildResidentialModel < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'Build Residential Model'
  end

  # human readable description
  def description
    return 'Builds the OpenStudio Model for an existing residential building.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Builds the residential OpenStudio Model using the geojson feature file, which contains the specified parameters for each existing building.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    arg = OpenStudio::Ruleset::OSArgument.makeIntegerArgument('urbanopt_feature_id', true)
    arg.setDisplayName('URBANopt: GeoJSON Feature ID')
    arg.setDescription('The feature ID passed from Baseline.rb.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('resstock_buildstock_csv_path', false)
    arg.setDisplayName('ResStock: Buildstock CSV File Path')
    arg.setDescription('Absolute path of the buildstock CSV file.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('resstock_building_id', false)
    arg.setDisplayName('ResStock: Building Unit ID')
    arg.setDescription('The building unit number (between 1 and the number of samples).')
    args << arg

    schedules_type_choices = OpenStudio::StringVector.new
    schedules_type_choices << 'smooth'
    schedules_type_choices << 'stochastic'

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('schedules_type', schedules_type_choices, true)
    arg.setDisplayName('Schedules: Type')
    arg.setDescription('The type of occupant-related schedules to use.')
    arg.setDefaultValue('smooth')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('schedules_random_seed', true)
    arg.setDisplayName('Schedules: Random Seed')
    arg.setUnits('#')
    arg.setDescription("This numeric field is the seed for the random number generator. Only applies if the schedules type is 'stochastic'.")
    args << arg

    schedules_variation_choices = OpenStudio::StringVector.new
    schedules_variation_choices << 'unit'
    schedules_variation_choices << 'building'

    arg = OpenStudio::Ruleset::OSArgument.makeChoiceArgument('schedules_variation', schedules_variation_choices, true)
    arg.setDisplayName('Schedules: Variation')
    arg.setDescription('How the schedules vary.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('geometry_num_floors_above_grade', true)
    arg.setDisplayName('Geometry: Number of Floors Above Grade')
    arg.setUnits('#')
    arg.setDescription('The number of floors above grade.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('hpxml_dir', false)
    arg.setDisplayName('Folder Containing Custom HPXML File')
    arg.setDescription('The name of the folder containing a custom HPXML file, relative to the xml_building folder.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('output_dir', true)
    arg.setDisplayName('Directory for Output Files')
    arg.setDescription('Absolute/relative path for the output files directory.')
    args << arg

    measures_dir = File.absolute_path(File.join(File.dirname(__FILE__), '../../resources/residential-measures/resources/hpxml-measures'))
    measure_subdir = 'BuildResidentialHPXML'
    full_measure_path = File.join(measures_dir, measure_subdir, 'measure.rb')
    measure = get_measure_instance(full_measure_path)

    measure.arguments(model).each do |arg|
      args << arg
    end

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    args = runner.getArgumentValues(arguments(model), user_arguments)

    # optionals: get or remove
    # args.each_key do |arg|
    #   if args[arg].is_initialized
    #     args[arg] = args[arg].get
    #   else
    #     args.delete(arg)
    #   end
    # rescue StandardError # this is needed for when args[arg] is actually a value
    # end

    # Get file/dir paths
    resources_dir = File.absolute_path(File.join(File.dirname(__FILE__), '../../resources'))
    residential_measures_dir = File.join(resources_dir, 'residential-measures')
    hpxml_measures_dir = File.join(residential_measures_dir, 'resources/hpxml-measures')

    # Check file/dir paths exist
    check_dir_exists(resources_dir, runner)
    check_dir_exists(residential_measures_dir, runner)
    check_dir_exists(hpxml_measures_dir, runner)

    # Either:
    # (A) Assign ResStock options; all units of the building are identical
    # (B) Create units of the building using logic in get_unit_positions()
    # (C) Run an HPXML file that has already been created
    if args.key?(:resstock_buildstock_csv_path) && args.key?(:resstock_building_id) # assign resstock options
      buildstock_csv_path = args[:resstock_buildstock_csv_path]
      building_id = args[:resstock_building_id]

      if building_id == 0
        runner.registerError("Feature ID = #{args[:urbanopt_feature_id]}: No matching buildstock building ID found.")
        return false
      end

      # Get file/dir paths
      characteristics_dir = File.join(residential_measures_dir, 'project_national/housing_characteristics')
      measures_dir = File.join(residential_measures_dir, 'measures')
      lookup_file = File.join(residential_measures_dir, 'resources/options_lookup.tsv')

      # Check file/dir paths exist
      check_dir_exists(characteristics_dir, runner)
      check_dir_exists(measures_dir, runner)
      check_file_exists(lookup_file, runner)
      check_file_exists(buildstock_csv_path, runner)

      lookup_csv_data = CSV.open(lookup_file, col_sep: "\t").each.to_a

      # Retrieve all data associated with sample number
      bldg_data = get_data_for_sample(buildstock_csv_path, building_id, runner)

      # Retrieve order of parameters to run
      parameters_ordered = get_parameters_ordered_from_options_lookup_tsv(lookup_csv_data, characteristics_dir)

      # Check buildstock.csv has all parameters
      missings = parameters_ordered - bldg_data.keys
      if !missings.empty?
        # The following is a warning and not an error because we support uo_buildstock_mapping_csv_path having a subset of all parameters
        runner.registerWarning("Mismatch between buildstock.csv and options_lookup.tsv. Missing parameters: #{missings.join(', ')}.")
      end

      # Check buildstock.csv doesn't have extra parameters
      extras = bldg_data.keys - parameters_ordered - ['Feature ID', 'Building', 'sample_weight']
      if !extras.empty?
        runner.registerError("Mismatch between buildstock.csv and options_lookup.tsv. Extra parameters: #{extras.join(', ')}.")
        return false
      end

      # Retrieve options that have been selected for this building_id
      parameters_ordered.each do |parameter_name|
        # Register the option chosen for parameter_name with the runner
        option_name = bldg_data[parameter_name]
        next if option_name.nil? # can be nil if parameter doesn't exist

        register_value(runner, parameter_name, option_name)
      end

      # Obtain measures and arguments to be called
      measures = {}
      parameters_ordered.each do |parameter_name|
        option_name = bldg_data[parameter_name]
        next if option_name.nil? # can be nil if parameter doesn't exist

        print_option_assignment(parameter_name, option_name, runner)
        options_measure_args, _errors = get_measure_args_from_option_names(lookup_csv_data, [option_name], parameter_name, lookup_file, runner)
        options_measure_args[option_name].each do |measure_subdir, args_hash|
          update_args_hash(measures, measure_subdir, args_hash)
        end
      end

      # Fill in defaults where any missing parameters from the buildstock csv haven't assigned arguments
      args.each_key do |arg_name|
        measures['ResStockArguments'][0][arg_name.to_s] = args[arg_name].to_s if measures['ResStockArguments'][0][arg_name.to_s].nil?
      end

      # ResStockArguments
      measure_subdir = 'ResStockArguments'
      measures['ResStockArguments'][0]['building_id'] = building_id
      full_measure_path = File.join(measures_dir, measure_subdir, 'measure.rb')
      check_file_exists(full_measure_path, runner)

      # Don't assign arguments from this measure to ResStockArguments
      measure = get_measure_instance(full_measure_path)
      arg_names = measure.arguments(model).collect { |arg| arg.name.to_sym }
      args_to_delete = args.keys - arg_names
      args_to_delete.each do |arg_to_delete|
        measures['ResStockArguments'][0].delete(arg_to_delete.to_s)
      end

      # Apply the ResStockArguments measure
      resstock_arguments_runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new) # we want only ResStockArguments registered argument values
      if !apply_measures(measures_dir, { 'ResStockArguments' => measures['ResStockArguments'] }, resstock_arguments_runner, model, true, 'OpenStudio::Measure::ModelMeasure', nil)
        register_logs(runner, resstock_arguments_runner)
        return false
      end

      # Transfer output of ResStockArguments over to the args hash, which will feed into BuildResidentialHPXML
      resstock_arguments_runner.result.stepValues.each do |step_value|
        value = get_value_from_workflow_step_value(step_value)
        next if value == ''
        next if skip_step_value(step_value, args)

        args[step_value.name.to_sym] = value
      end

      units = []
      geometry_building_num_units = 1
      geometry_building_num_units = Integer(args[:geometry_building_num_units]) if args.key?(:geometry_building_num_units)
      (1..geometry_building_num_units).to_a.each do |unit_num|
        units << {}
      end
      standards_number_of_living_units = units.size
    elsif args[:hpxml_dir].nil? # create units of the building
      units = get_unit_positions(runner, args)
      if units.empty?
        return false
      end

      standards_number_of_living_units = units.size
    else # get pre-made units
      xml_building_folder = "xml_building"
      hpxml_dir = File.join(File.dirname(__FILE__), "../../#{xml_building_folder}/#{args[:hpxml_dir]}")

      if !File.exist?(hpxml_dir)
        runner.registerError("HPXML directory '#{File.join(xml_building_folder, File.basename(hpxml_dir))}' was specified for feature ID = #{args[:urbanopt_feature_id]}, but could not be found.")
        return false
      end

      units = []
      hpxml_paths = Dir["#{hpxml_dir}/*.xml"]
      if hpxml_paths.size != 1
        runner.registerError("HPXML directory '#{File.join(xml_building_folder, File.basename(hpxml_dir))}' must contain exactly 1 HPXML file; the single file can describe multiple dwelling units of a feature.")
        return false
      end
      hpxml_path = hpxml_paths[0]
      units << { 'hpxml_path' => hpxml_path }

      hpxml = HPXML.new(hpxml_path: hpxml_path)
      standards_number_of_living_units = 0
      hpxml.buildings.each do |hpxml_bldg|
        number_of_units = 1
        number_of_units = hpxml_bldg.building_construction.number_of_units if !hpxml_bldg.building_construction.number_of_units.nil?
        standards_number_of_living_units += number_of_units
      end
    end

    if args.key?(:geometry_building_num_units) && (standards_number_of_living_units != Integer(args[:geometry_building_num_units]))
      runner.registerError("The number of actual dwelling units (#{standards_number_of_living_units}) differs from the specified number of units (#{Integer(args[:geometry_building_num_units])}).")
      return false
    end

    hpxml_path = File.expand_path(args[:hpxml_path])
    units.each_with_index do |unit, unit_num|

      measures = {}
      if !unit.key?('hpxml_path') # create a single new HPXML file describing all dwelling units of the feature

        whole_sfa_or_mf_building_sim = true

        # BuildResidentialHPXML
        measure_subdir = 'BuildResidentialHPXML'
        full_measure_path = File.join(hpxml_measures_dir, measure_subdir, 'measure.rb')
        check_file_exists(full_measure_path, runner)

        measure_args = args.clone.collect { |k, v| [k.to_s, v] }.to_h
        measure_args['hpxml_path'] = hpxml_path
        if unit_num > 0
          measure_args['existing_hpxml_path'] = hpxml_path
          measure_args['battery_present'] = 'false' # limitation of OS-HPXML
        end

        # Set whole SFA/MF building simulation items
        measure_args['whole_sfa_or_mf_building_sim'] = whole_sfa_or_mf_building_sim

        measure_args['software_info_program_used'] = 'URBANopt'
        begin
          version_rb File.absolute_path(File.join(File.dirname(__FILE__), '../../../lib/uo_cli/version.rb'))
          require version_rb
          measure_args['software_info_program_version'] = URBANopt::CLI::VERSION
        rescue StandardError
          measure_args['software_info_program_version'] = '0.11.0' # FIXME: is there a way to get the version of urbanopt-example-geojson-project?
        end
        measure_args['apply_defaults'] = true

        measure_args['geometry_unit_left_wall_is_adiabatic'] = unit['geometry_unit_left_wall_is_adiabatic'] if unit.key?('geometry_unit_left_wall_is_adiabatic')
        measure_args['geometry_unit_right_wall_is_adiabatic'] = unit['geometry_unit_right_wall_is_adiabatic'] if unit.key?('geometry_unit_right_wall_is_adiabatic')
        measure_args['geometry_unit_front_wall_is_adiabatic'] = unit['geometry_unit_front_wall_is_adiabatic'] if unit.key?('geometry_unit_front_wall_is_adiabatic')
        measure_args['geometry_unit_back_wall_is_adiabatic'] = unit['geometry_unit_back_wall_is_adiabatic'] if unit.key?('geometry_unit_back_wall_is_adiabatic')
        measure_args['geometry_foundation_type'] = unit['geometry_foundation_type'] if unit.key?('geometry_foundation_type')
        measure_args['geometry_attic_type'] = unit['geometry_attic_type'] if unit.key?('geometry_attic_type')
        measure_args['geometry_unit_orientation'] = unit['geometry_unit_orientation'] if unit.key?('geometry_unit_orientation')

        # Don't assign arguments from this measure to BuildResidentialHPXML
        measure = get_measure_instance(full_measure_path)
        arg_names = measure.arguments(model).collect { |arg| arg.name.to_sym }
        args_to_delete = args.keys - arg_names
        args_to_delete.each do |arg_to_delete|
          measure_args.delete(arg_to_delete.to_s)
        end

        measures[measure_subdir] = [measure_args]

        if !apply_measures(hpxml_measures_dir, measures, runner, model, true, 'OpenStudio::Measure::ModelMeasure', nil)
          return false
        end
      else # we're using an HPXML file from the xml_building folder
        FileUtils.cp(File.expand_path(unit['hpxml_path']), hpxml_path)

      end
    end # end units.each_with_index do |unit, unit_num|

    # call BuildResidentialScheduleFile / HPXMLtoOpenStudio after HPXML file is created
    measures = {}

    # BuildResidentialScheduleFile
    if args[:schedules_type] == 'stochastic' # if smooth, don't run the measure; schedules type stochastic currently hardcoded in Baseline.rb
      measure_subdir = 'BuildResidentialScheduleFile'
      full_measure_path = File.join(hpxml_measures_dir, measure_subdir, 'measure.rb')
      check_file_exists(full_measure_path, runner)

      measure_args = {}
      measure_args['hpxml_path'] = hpxml_path
      measure_args['hpxml_output_path'] = hpxml_path
      measure_args['schedules_random_seed'] = args[:schedules_random_seed]
      measure_args['building_id'] = 'ALL' # FIXME: schedules variation by building currently not supported; by unit currently hardcoded in Baseline.rb
      measure_args['output_csv_path'] = 'schedules.csv'

      measures[measure_subdir] = [measure_args]
    end

    # HPXMLtoOpenStudio
    measure_subdir = 'HPXMLtoOpenStudio'
    full_measure_path = File.join(hpxml_measures_dir, measure_subdir, 'measure.rb')
    check_file_exists(full_measure_path, runner)

    measure_args = {}
    measure_args['hpxml_path'] = hpxml_path
    measure_args['output_dir'] = File.expand_path(args[:output_dir])
    measure_args['debug'] = true

    measures[measure_subdir] = [measure_args]

    if !apply_measures(hpxml_measures_dir, measures, runner, model, true, 'OpenStudio::Measure::ModelMeasure', nil)
      return false
    end

    # store metadata for default_feature_reports measure
    standards_number_of_above_ground_stories = Integer(args[:geometry_num_floors_above_grade])
    standards_number_of_stories = Integer(args[:geometry_num_floors_above_grade])
    number_of_conditioned_stories = Integer(args[:geometry_num_floors_above_grade])
    if ['UnconditionedBasement', 'ConditionedBasement'].include?(args[:geometry_foundation_type])
      standards_number_of_stories += 1
      if ['ConditionedBasement'].include?(args[:geometry_foundation_type])
        number_of_conditioned_stories += 1
      end
    end

    case args[:geometry_unit_type]
    when 'single-family detached'
      building_type = 'Single-Family Detached'
    when 'single-family attached'
      building_type = 'Single-Family Attached'
    when 'apartment unit'
      building_type = 'Multifamily'
    end

    model.getSpaces.each do |space|
      space_type = OpenStudio::Model::SpaceType.new(model)
      space_type.setStandardsSpaceType(space.name.to_s)
      space.setSpaceType(space_type)
    end

    model.getSpaceTypes.each do |space_type|
      next unless space_type.standardsSpaceType.is_initialized

      # set building_type on SpaceType for conditioned spaces to populate space_type_areas hash in default_feature_reports
      if space_type.standardsSpaceType.get.include?('conditioned space') || space_type.standardsSpaceType.get.include?('conditioned_space')
        space_type.setStandardsBuildingType(building_type)
      end
    end

    model.getBuilding.setStandardsBuildingType('Residential')
    model.getBuilding.setStandardsNumberOfAboveGroundStories(standards_number_of_above_ground_stories)
    model.getBuilding.setStandardsNumberOfStories(standards_number_of_stories)
    model.getBuilding.setNominalFloortoFloorHeight(Float(args[:geometry_average_ceiling_height]))
    model.getBuilding.setStandardsNumberOfLivingUnits(standards_number_of_living_units)
    model.getBuilding.additionalProperties.setFeature('NumberOfConditionedStories', number_of_conditioned_stories)

    return true
  end

  def get_unit_positions(runner, args)
    geometry_building_num_units = Integer(args[:geometry_building_num_units])
    geometry_num_floors_above_grade = Integer(args[:geometry_num_floors_above_grade])

    units = []
    case args[:geometry_unit_type]
    when 'single-family detached'
      units << {}
    when 'single-family attached'

      ###################################################
      #         #         #         #         #         #
      #         #         #         #         #         #
      #    1    #    2    #    3    #    4    #    5    #
      #         #         #         #         #         #
      #         #         #         #         #         #
      ###################################################

      (1..geometry_building_num_units).to_a.each do |unit_num|
        case unit_num
        when 1
          if geometry_building_num_units > 1
            units << { 'geometry_unit_left_wall_is_adiabatic' => true } # right end unit, one adiabatic wall
          else
            units << { 'geometry_unit_left_wall_is_adiabatic' => false } # only one unit, no adiabatic walls
          end
        when geometry_building_num_units
          units << { 'geometry_unit_right_wall_is_adiabatic' => true } # left end unit, one adiabatic wall
        else
          units << { 'geometry_unit_left_wall_is_adiabatic' => true,
                     'geometry_unit_right_wall_is_adiabatic' => true } # everything in between
        end
      end
    when 'apartment unit'

      #####################
      #         #         #
      #         #         #
      #    2    #    4    #
      #         #         #
      #         #         #
      ###############################
      #         #         #         #
      #         #         #         #
      #    1    #    3    #    5    #
      #         #         #         #
      #         #         #         #
      ###############################

      # If geometry_building_num_units < geometry_num_floors_above_grade, assume 1 unit per floor
      num_units_per_floor = (Float(geometry_building_num_units) / Float(geometry_num_floors_above_grade)).ceil

      floor = 1
      position = 1
      (1..geometry_building_num_units).to_a.each do |unit_num|
        geometry_unit_orientation = 180.0
        if position.even?
          geometry_unit_orientation = 0.0
        end

        geometry_unit_left_wall_is_adiabatic = true
        geometry_unit_right_wall_is_adiabatic = true
        geometry_unit_front_wall_is_adiabatic = false
        geometry_unit_back_wall_is_adiabatic = true

        if position == 1
          geometry_unit_right_wall_is_adiabatic = false
          geometry_unit_left_wall_is_adiabatic = false if num_units_per_floor == 2
        elsif position == 2
          geometry_unit_left_wall_is_adiabatic = false
          geometry_unit_right_wall_is_adiabatic = false if [2, 3].include?(num_units_per_floor)
        elsif position == num_units_per_floor and num_units_per_floor.even?
          geometry_unit_right_wall_is_adiabatic = false
        elsif position == num_units_per_floor and num_units_per_floor.odd?
          geometry_unit_left_wall_is_adiabatic = false
        elsif position + 1 == num_units_per_floor and num_units_per_floor.even?
          geometry_unit_left_wall_is_adiabatic = false
        elsif position + 1 == num_units_per_floor and num_units_per_floor.odd?
          geometry_unit_right_wall_is_adiabatic = false
        end

        if num_units_per_floor == 1
          geometry_unit_left_wall_is_adiabatic = false
          geometry_unit_right_wall_is_adiabatic = false
          geometry_unit_back_wall_is_adiabatic = false
        end

        geometry_foundation_type = args[:geometry_foundation_type]
        geometry_attic_type = args[:geometry_attic_type]

        if geometry_num_floors_above_grade > 1
          case floor
          when 1
            geometry_attic_type = 'BelowApartment'
          when geometry_num_floors_above_grade
            geometry_foundation_type = 'AboveApartment'
          else
            geometry_foundation_type = 'AboveApartment'
            geometry_attic_type = 'BelowApartment'
          end
        end

        if unit_num % num_units_per_floor == 0
          floor += 1
          position = 0
        end
        position += 1

        units << { 'geometry_unit_left_wall_is_adiabatic' => geometry_unit_left_wall_is_adiabatic,
                   'geometry_unit_right_wall_is_adiabatic' => geometry_unit_right_wall_is_adiabatic,
                   'geometry_unit_front_wall_is_adiabatic' => geometry_unit_front_wall_is_adiabatic,
                   'geometry_unit_back_wall_is_adiabatic' => geometry_unit_back_wall_is_adiabatic,
                   'geometry_foundation_type' => geometry_foundation_type,
                   'geometry_attic_type' => geometry_attic_type,
                   'geometry_unit_orientation' => geometry_unit_orientation }
      end
    end
    return units
  end

  def skip_step_value(step_value, args)
    # Avoid overwriting the following arguments with values from the lookup -- they are either:
    # - geometry related arguments that won't conflict with other lookup options (e.g., geometry_unit_cfa)
    # - weather related arguments that area already specified in the GeoJSON file (e.g., weather_station_epw_filepath)

    # Geometry Floor Area
    return true if step_value.name == 'geometry_unit_cfa'

    # County
    return true if step_value.name == 'simulation_control_daylight_saving_enabled'
    return true if step_value.name == 'weather_station_epw_filepath'
    return true if step_value.name == 'site_zip_code'
    return true if step_value.name == 'site_time_zone_utc_offset'

    # State
    return true if step_value.name == 'site_state_code'

    # ASHRAE IECC Climate Zone 2004
    return true if step_value.name == 'site_iecc_zone'

    # Vintage
    return true if step_value.name == 'year_built' && args.key?(:year_built)

    return false
  end
end

# register the measure to be used by the application
BuildResidentialModel.new.registerWithApplication
