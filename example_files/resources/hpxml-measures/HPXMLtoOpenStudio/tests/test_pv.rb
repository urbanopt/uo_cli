# frozen_string_literal: true

require_relative '../resources/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'
require_relative '../measure.rb'
require_relative '../resources/util.rb'

class HPXMLtoOpenStudioPVTest < MiniTest::Test
  def sample_files_dir
    File.join(File.dirname(__FILE__), '..', '..', 'workflow', 'sample_files')
  end

  def get_generator_inverter(model, name)
    generator = nil
    inverter = nil
    model.getGeneratorPVWattss.each do |g|
      next unless g.name.to_s.start_with? "#{name} "

      generator = g
    end
    model.getElectricLoadCenterInverterPVWattss.each do |i|
      next unless i.name.to_s.start_with? "#{name} "

      inverter = i
    end
    [generator, inverter]
  end

  def test_pv
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-pv.xml'))
    model, hpxml = _test_measure(args_hash)

    hpxml.pv_systems.each do |pv_system|
      generator, inverter = get_generator_inverter(model, pv_system.id)

      # Check PV
      assert_equal(pv_system.array_tilt, generator.tiltAngle)
      assert_equal(pv_system.array_azimuth, generator.azimuthAngle)
      assert_equal(pv_system.max_power_output, generator.dcSystemCapacity)
      assert_equal(pv_system.system_losses_fraction, generator.systemLosses)
      assert_equal(pv_system.module_type, generator.moduleType.downcase)
      assert_equal('FixedRoofMounted', generator.arrayType)

      # Check inverter
      assert_equal(pv_system.inverter_efficiency, inverter.inverterEfficiency)
    end
  end

  def test_pv_shared
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-pv-shared.xml'))
    model, hpxml = _test_measure(args_hash)

    hpxml.pv_systems.each do |pv_system|
      generator, inverter = get_generator_inverter(model, pv_system.id)

      # Check PV
      max_power = pv_system.max_power_output * hpxml.building_construction.number_of_bedrooms.to_f / pv_system.number_of_bedrooms_served.to_f
      assert_equal(pv_system.array_tilt, generator.tiltAngle)
      assert_equal(pv_system.array_azimuth, generator.azimuthAngle)
      assert_equal(max_power, generator.dcSystemCapacity)
      assert_equal(pv_system.system_losses_fraction, generator.systemLosses)
      assert_equal(pv_system.module_type, generator.moduleType.downcase)
      assert_equal('FixedOpenRack', generator.arrayType)

      # Check inverter
      assert_equal(pv_system.inverter_efficiency, inverter.inverterEfficiency)
    end
  end

  def _test_measure(args_hash)
    # create an instance of the measure
    measure = HPXMLtoOpenStudio.new

    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
    model = OpenStudio::Model::Model.new

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash.key?(arg.name)
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result) unless result.value.valueName == 'Success'

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)

    hpxml = HPXML.new(hpxml_path: args_hash['hpxml_path'])

    [model, hpxml]
  end
end
