# How to adapt to a new ResStock version

1. Update branch_or_tag for ResStock in Rakefile
    - May need to create a new branch on ResStock for a stable source
1. Update residential resources with the Rake task
1. Open the appropriate geojson file to read the inputs by hand
    - Residential tests use [this file](https://github.com/urbanopt/urbanopt-example-geojson-project/blob/develop/example_project/example_project_combined.json)
1. Open the [test buildstock.csv](https://github.com/urbanopt/urbanopt-example-geojson-project/blob/develop/example_project/resources/residential-measures/test/base_results/baseline/annual/buildstock.csv) file in Excel to downselect by hand
1. Use Excel filtering to only view the relevant characteristics as defined by the geojson.
    - `test_residential_samples3` in [the residential measure test](https://github.com/urbanopt/urbanopt-example-geojson-project/blob/develop/example_project/measures/BuildResidentialModel/tests/test_build_residential_model.rb) specifies IDs [14, 15, 16]
    - Go to feature 14 in the geojson, and downselect the buildstock.csv based on the criteria in that feature
        - Mapping between geojson names & buildstock columns can be found in the [_apply_residential_samples method](https://github.com/urbanopt/urbanopt-example-geojson-project/blob/develop/example_project/measures/BuildResidentialModel/tests/test_build_residential_model.rb#L494), if you use a little imagination
    - Once you have downselected to only a few buildings, pick one at random to be the new building 14
    - Copy all the header columns from buildstock.csv
1. Open [this mapping file](https://github.com/urbanopt/urbanopt-example-geojson-project/blob/develop/example_project/resources/uo_buildstock_mapping.csv) to set our connection to the new version of ResStock
    - Replace the header copied from buildstock.csv with the header from the updated version of ResStock that you just copied
    - Replace the data row for building 14, keeping the Feature ID column
1. Repeat the previous 2 steps for buildings 15 & 16
    - Save the new mapping file
1. Copy the new mapping file and remove the Feature ID column
    - Place the one without the Feature ID column in the example_project/measures/BuildResidentialModel/tests/samples folder
1. Test the residential measure with the Rake task
1. Run the rspec tests
