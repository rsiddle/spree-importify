Import
-------

Based on the original import script by Torsten Rüger https://github.com/ikido/

But it works (at least for me) with rake products:import

Edit at will, contribute if possible.

Base Directoy
-------------
All data for the import is assumed under vendor/import. Product folders should be created for each new import. The naming convention is:
vendor/import/products1
vendor/import/products2
vendor/import/productsXXX
etc.

Mapping
-------
Import assumes you have data from somewhere else, with headers that do not match the spree headers. A mapping.yml is assumed to exist in the base direcory. The mapping is a hash from the headers you have (string) to the spree headers (symbol). The spree headers you need are the ones you want setting, corresponding to the spree product/variant fields.

- name
- description
- web_price		will be used as price if mapped
- price			otherwise :price will be used (one of the two is mandatory)
- sku			your unique identifier
- image			the filename must be found somewhere under the base dir
- option 		used as the option type for a product and an option value for a variant (see below on variants)
- quantity 		the spree on_hand 
- category1 		category 1-3 can be used to set a 3 level category. If that doesn't fit your needs, override set_category 
- weight 		rest are self explanitory
- depth
- width
- height

Files
-----
All .csv files in the base directory will be loaded. 

The implementation assumes tab delimited columns. But as it uses fastercsv, you can change it to tab seperated (.tsv or .txt files).

Images can anywhere under the base directory

Adapt
-----
This is meant as a starting point, though hopefully it should be easy to adapt.

The is a somewhat document MyImport class in lib/ which you can change to your needs.

TODO
----
- Allow infinite images to be uploaded
- Don't upload duplicate images to the master when it should be only for the variant
- Allow multiple categories to be uploaded
- Allow custom product properties to be added in seperate columns
- Find a better way of creating new products when a product or its variants are not found
- Refactor code
- Testing!

Contribute
----------
Please contribute to help make this extension work for everyone. All new functionality, comments, patches/fixes welcome.
