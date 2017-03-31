Kong API Gateway Managers
-------------------------

Ruby scripts to maintain and sync up api definitions with Kong API Gateway. Requires ruby >= 1.9

## API Manager

`apimanager.rb` syncs up api definitions defined in yaml or json format. Sample yml provided in `api_sample.yml`. Note that plugin config defined in the yml file do not have the `config.` prefix, the prefix is added by the script.

```shell
Usage: ruby apimanager.rb [options]
    -a, --adminuri [URI]             Kong Admin Uri Base, default http://localhost:8001
    -c, --config [CONFIG]            Config YAML/JSON file with api definitions, default kong.yml
    -h, --help                      Show this message
```