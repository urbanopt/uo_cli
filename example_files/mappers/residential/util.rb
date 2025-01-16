# *********************************************************************************
# URBANopt (tm), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-example-geojson-project/blob/develop/LICENSE.md
# *********************************************************************************

def residential(scenario, feature, args, building_type)
  '''Assign arguments from geojson file.'''

  # Schedules
  feature_ids = []
  scenario.feature_file.features.each do |f|
    feature_ids << f.id
  end

  # BuildResidentialModel arguments
  args[:hpxml_path] = '../feature.xml'
  args[:output_dir] = '..'
  args[:urbanopt_feature_id] = feature.id
  args[:schedules_type] = 'stochastic' # smooth or stochastic
  args[:schedules_random_seed] = feature_ids.index(feature.id)
  args[:schedules_variation] = 'unit' # building or unit
  args[:geometry_num_floors_above_grade] = feature.number_of_stories_above_ground

  # Optionals
  number_of_residential_units = 1
  begin
    number_of_residential_units = feature.number_of_residential_units
  rescue StandardError
  end
  args[:geometry_building_num_units] = number_of_residential_units

  begin
    args[:hpxml_dir] = feature.hpxml_directory
    return
  rescue StandardError
  end

  timestep = 60
  begin
    timestep = 60 / feature.timesteps_per_hour
  rescue StandardError
  end

  run_period = 'Jan 1 - Dec 31'
  calendar_year = 2007
  begin
    abbr_monthnames = Date::ABBR_MONTHNAMES
    begin_month = abbr_monthnames[feature.begin_date[5, 2].to_i]
    begin_day_of_month = feature.begin_date[8, 2].to_i
    end_month = abbr_monthnames[feature.end_date[5, 2].to_i]
    end_day_of_month = feature.end_date[8, 2].to_i
    run_period = "#{begin_month} #{begin_day_of_month} - #{end_month} #{end_day_of_month}"
    calendar_year = feature.begin_date[0, 4].to_i
  rescue StandardError
  end

  year_built = 2000
  # OS-HPXML requires a year_built to set air leakage as of 1.9.0
  # https://openstudio-hpxml.readthedocs.io/en/latest/workflow_inputs.html#id117 (footnote 56sd)
  begin
    year_built = feature.year_built
  rescue StandardError
  end

  occupancy_calculation_type = nil
  begin
    occupancy_calculation_type = feature.occupancy_calculation_type
  rescue StandardError
  end

  number_of_occupants = nil
  begin
    number_of_occupants = feature.number_of_occupants
  rescue StandardError
  end

  maximum_roof_height = 8.0 * args[:geometry_num_floors_above_grade]
  begin
    maximum_roof_height = feature.maximum_roof_height
  rescue StandardError
  end

  roof_type = 'Gable'
  begin
    roof_type = feature.roof_type
  rescue StandardError
  end

  geometry_unit_orientation = nil
  begin
    geometry_unit_orientation = feature.geometry_unit_orientation
  rescue StandardError
  end

  geometry_unit_aspect_ratio = nil
  begin
    geometry_unit_aspect_ratio = feature.geometry_unit_aspect_ratio
  rescue StandardError
  end

  onsite_parking_fraction = false
  begin
    onsite_parking_fraction = feature.onsite_parking_fraction
  rescue StandardError
  end

  system_type = 'Residential - furnace and central air conditioner'
  begin
    system_type = feature.system_type
  rescue StandardError
  end

  heating_system_fuel_type = 'natural gas'
  begin
    heating_system_fuel_type = feature.heating_system_fuel_type
  rescue StandardError
  end

  # Apply residential
  residential_simulation(args, timestep, run_period, calendar_year, feature.weather_filename, year_built)
  residential_geometry_unit(args, building_type, feature.floor_area, feature.number_of_bedrooms, geometry_unit_orientation, geometry_unit_aspect_ratio, occupancy_calculation_type, number_of_occupants, maximum_roof_height)
  residential_geometry_foundation(args, feature.foundation_type)
  residential_geometry_attic(args, feature.attic_type, roof_type)
  residential_geometry_garage(args, onsite_parking_fraction)
  residential_geometry_neighbor(args)
  residential_hvac(args, system_type, heating_system_fuel_type)
  residential_appliances(args)
end

def residential_simulation(args, timestep, run_period, calendar_year, weather_filename, year_built)
  args[:simulation_control_timestep] = timestep
  args[:simulation_control_run_period] = run_period
  args[:simulation_control_run_period_calendar_year] = calendar_year
  args[:weather_station_epw_filepath] = "../../../../../weather/#{weather_filename}"
  args[:year_built] = year_built
end

def residential_geometry_unit(args, building_type, floor_area, number_of_bedrooms, geometry_unit_orientation, geometry_unit_aspect_ratio, occupancy_calculation_type, number_of_occupants, maximum_roof_height)
  number_of_stories_above_ground = args[:geometry_num_floors_above_grade]
  args[:geometry_unit_num_floors_above_grade] = 1
  case building_type
  when 'Single-Family Detached'
    args[:geometry_building_num_units] = 1
    args[:geometry_unit_type] = 'single-family detached'
    args[:geometry_unit_num_floors_above_grade] = number_of_stories_above_ground
  when 'Single-Family Attached'
    args[:geometry_unit_type] = 'single-family attached'
    args[:geometry_unit_num_floors_above_grade] = number_of_stories_above_ground
    args[:air_leakage_type] = 'unit total' # consistent with ResStock
  when 'Multifamily'
    args[:geometry_unit_type] = 'apartment unit'
    args[:air_leakage_type] = 'unit total' # consistent with ResStock
  end

  args[:geometry_unit_cfa] = floor_area / args[:geometry_building_num_units]

  args[:geometry_unit_num_bedrooms] = number_of_bedrooms / args[:geometry_building_num_units]

  # Geometry Orientation and Aspect Ratio
  # Orientation (North=0, East=90, South=180, West=270)
  args[:geometry_unit_orientation] = geometry_unit_orientation if !geometry_unit_orientation.nil?

  # Aspect Ratio
  # The ratio of front/back wall length to left/right wall length for the unit, excluding any protruding garage wall area.
  args[:geometry_unit_aspect_ratio] = geometry_unit_aspect_ratio if !geometry_unit_aspect_ratio.nil?

  # Occupancy Calculation Type
  if occupancy_calculation_type == 'operational'
    # set args[:geometry_unit_num_occupants]
    begin
      args[:geometry_unit_num_occupants] = number_of_occupants / args[:geometry_building_num_units]
    rescue StandardError # number_of_occupants is not defined: assume equal to number of bedrooms
      args[:geometry_unit_num_occupants] = args[:geometry_unit_num_bedrooms]
    end
  else # nil or asset
    # do not set args[:geometry_unit_num_occupants]
  end

  args[:geometry_average_ceiling_height] = maximum_roof_height / number_of_stories_above_ground
end

def residential_geometry_foundation(args, foundation_type)
  args[:geometry_foundation_type] = 'SlabOnGrade'
  args[:geometry_foundation_height] = 0.0
  case foundation_type
  when 'crawlspace - vented'
    args[:geometry_foundation_type] = 'VentedCrawlspace'
    args[:geometry_foundation_height] = 3.0
  when 'crawlspace - unvented'
    args[:geometry_foundation_type] = 'UnventedCrawlspace'
    args[:geometry_foundation_height] = 3.0
  when 'crawlspace - conditioned'
    args[:geometry_foundation_type] = 'ConditionedCrawlspace'
    args[:geometry_foundation_height] = 3.0
  when 'basement - unconditioned'
    args[:geometry_foundation_type] = 'UnconditionedBasement'
    args[:geometry_foundation_height] = 8.0
  when 'basement - conditioned'
    args[:geometry_foundation_type] = 'ConditionedBasement'
    args[:geometry_foundation_height] = 8.0
  when 'ambient'
    args[:geometry_foundation_type] = 'Ambient'
    args[:geometry_foundation_height] = 8.0
  end
end

def residential_geometry_attic(args, attic_type, roof_type)
  begin
    case attic_type
    when 'attic - vented'
      args[:geometry_attic_type] = 'VentedAttic'
    when 'attic - unvented'
      args[:geometry_attic_type] = 'UnventedAttic'
    when 'attic - conditioned'
      args[:geometry_attic_type] = 'ConditionedAttic'
    when 'flat roof'
      args[:geometry_attic_type] = 'FlatRoof'
    end
  rescue StandardError
  end

  case roof_type
  when 'Gable'
    args[:geometry_roof_type] = 'gable'
  when 'Hip'
    args[:geometry_roof_type] = 'hip'
  end
end

def residential_geometry_garage(args, onsite_parking_fraction)
  num_garage_spaces = 0
  if onsite_parking_fraction
    num_garage_spaces = 1
    if args[:geometry_unit_cfa] > 2500.0
      num_garage_spaces = 2
    end
  end
  args[:geometry_garage_width] = 12.0 * num_garage_spaces
  args[:geometry_garage_protrusion] = 1.0
end

def residential_geometry_neighbor(args)
  args[:neighbor_left_distance] = 0.0
  args[:neighbor_right_distance] = 0.0
end

def residential_hvac(args, system_type, heating_system_fuel_type)
  args[:heating_system_type] = 'none'
  if system_type.include?('electric resistance')
    args[:heating_system_type] = 'ElectricResistance'
  elsif system_type.include?('furnace')
    args[:heating_system_type] = 'Furnace'
  elsif system_type.include?('boiler')
    args[:heating_system_type] = 'Boiler'
  end

  args[:cooling_system_type] = 'none'
  if system_type.include?('central air conditioner')
    args[:cooling_system_type] = 'central air conditioner'
  elsif system_type.include?('room air conditioner')
    args[:cooling_system_type] = 'room air conditioner'
    args[:cooling_system_cooling_efficiency_type] = 'EER'
    args[:cooling_system_cooling_efficiency] = 8.5
  elsif system_type.include?('evaporative cooler')
    args[:cooling_system_type] = 'evaporative cooler'
  end

  args[:heat_pump_type] = 'none'
  if system_type.include?('air-to-air')
    args[:heat_pump_type] = 'air-to-air'
  elsif system_type.include?('mini-split')
    args[:heat_pump_type] = 'mini-split'
  elsif system_type.include?('ground-to-air')
    args[:heat_pump_type] = 'ground-to-air'
    args[:heat_pump_heating_efficiency_type] = 'COP'
    args[:heat_pump_heating_efficiency] = 3.6
    args[:heat_pump_cooling_efficiency_type] = 'EER'
    args[:heat_pump_cooling_efficiency] = 17.1
  end

  args[:heating_system_fuel] = heating_system_fuel_type
  if args[:heating_system_type] == 'ElectricResistance'
    args[:heating_system_fuel] = 'electricity'
  end

  if args[:heating_system_fuel] == 'electricity'
    args[:heating_system_heating_efficiency] = 1.0
  end
end

def residential_appliances(args)
  args[:cooking_range_oven_fuel_type] = args[:heating_system_fuel]
  args[:clothes_dryer_fuel_type] = args[:heating_system_fuel]
  args[:water_heater_fuel_type] = args[:heating_system_fuel]
end
