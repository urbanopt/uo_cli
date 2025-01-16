# *********************************************************************************
# URBANopt (tm), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-example-geojson-project/blob/develop/LICENSE.md
# *********************************************************************************

def residential_template(args, template, climate_zone)
  '''Assign arguments from tsv files.'''

  # IECC / EnergyStar / Other
  if template.include?('Residential IECC')

    captures = template.match(/Residential IECC (?<iecc_year>\d+) - Customizable Template (?<t_month>\w+) (?<t_year>\d+)/)
    template_vals = Hash[captures.names.zip(captures.captures)]
    template_vals = template_vals.transform_keys(&:to_sym)
    template_vals[:climate_zone] = climate_zone

    # ENCLOSURE

    enclosure_filepath = File.join(File.dirname(__FILE__), 'iecc/enclosure.tsv')
    enclosure = get_lookup_tsv(args, enclosure_filepath)
    row = get_lookup_row(args, enclosure, template_vals)

    # Determine which surfaces to place insulation on
    if args[:geometry_foundation_type].include? 'Basement'
      row[:foundation_wall_assembly_r] = row[:foundation_wall_assembly_r_basement]
      row[:floor_over_foundation_assembly_r] = 2.1
      row[:floor_over_garage_assembly_r] = 2.1
    elsif args[:geometry_foundation_type].include? 'Crawlspace'
      row[:foundation_wall_assembly_r] = row[:foundation_wall_assembly_r_crawlspace]
      row[:floor_over_foundation_assembly_r] = 2.1
      row[:floor_over_garage_assembly_r] = 2.1
    end
    row.delete(:foundation_wall_assembly_r_basement)
    row.delete(:foundation_wall_assembly_r_crawlspace)
    if ['ConditionedAttic'].include?(args[:geometry_attic_type])
      row[:roof_assembly_r] = row[:ceiling_assembly_r]
      row[:ceiling_assembly_r] = 2.1
    end
    args.update(row) unless row.nil?

    # HVAC

    { args[:heating_system_type] => 'iecc/heating_system.tsv', 
      args[:cooling_system_type] => 'iecc/cooling_system.tsv',
      args[:heat_pump_type] => 'iecc/heat_pump.tsv' }.each do |type, path|

      if type != 'none'
        filepath = File.join(File.dirname(__FILE__), path)
        lookup_tsv = get_lookup_tsv(args, filepath)
        row = get_lookup_row(args, lookup_tsv, template_vals)
        args.update(row) unless row.nil?
      end
    end

    # APPLIANCES / MECHANICAL VENTILATION / WATER HEATER

    ['refrigerator', 'clothes_washer', 'dishwasher', 'clothes_dryer', 'mechanical_ventilation', 'water_heater'].each do |appliance|
      filepath = File.join(File.dirname(__FILE__), "iecc/#{appliance}.tsv")
      lookup_tsv = get_lookup_tsv(args, filepath)
      row = get_lookup_row(args, lookup_tsv, template_vals)
      args.update(row) unless row.nil?
    end
  end
end

def get_lookup_tsv(args, filepath)
  rows = []
  headers = []
  units = []
  CSV.foreach(filepath, col_sep: "\t") do |row|
    if headers.empty?
      row.each do |header|
        next if header == 'Source'

        if args.key?(header.gsub('Dependency=', '').to_sym)
          header = header.gsub('Dependency=', '')
        end
        unless header.include?('Dependency=')
          header = header.to_sym
        end
        headers << header
      end
      next
    elsif units.empty?
      row.each do |unit|
        units << unit
      end
      next
    end
    if headers.length != row.length
      row = row[0..-2] # leave out Source column
    end
    rows << headers.zip(row).to_h
  end
  return rows
end

def get_lookup_row(args, rows, template_vals)
  rows.each do |row|
    if row.key?('Dependency=Climate Zone') && (row['Dependency=Climate Zone'] != template_vals[:climate_zone])
      next
    end
    if row.key?('Dependency=IECC Year') && (row['Dependency=IECC Year'] != template_vals[:iecc_year])
      next
    end
    if row.key?('Dependency=Template Month') && (row['Dependency=Template Month'] != template_vals[:t_month])
      next
    end
    if row.key?('Dependency=Template Year') && (row['Dependency=Template Year'] != template_vals[:t_year])
      next
    end

    row.delete('Dependency=Climate Zone')
    row.delete('Dependency=IECC Year')
    row.delete('Dependency=Template Month')
    row.delete('Dependency=Template Year')

    row.each do |k, v|
      next unless v.nil?

      row.delete(k)
    end

    intersection = args.keys & row.keys
    return row if intersection.empty? # found the correct row

    skip = false
    intersection.each do |k|
      if args[k] != row[k]
        skip = true
      end
    end

    return row unless skip
  end
  return nil
end
