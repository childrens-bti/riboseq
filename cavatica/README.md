# Cavatica port documentation

This document provides instructions for developers on how to port the `riboseq` workflow to Cavatica, a cloud-based platform for running bioinformatics workflows.

Instructions for Cavatica users can be found in the [Cavatica documentation](sb_doc.md) file.

## Instructions for developers

### Software installation

The software used for porting to Cavatica is `sbpack`, available at <https://github.com/rabix/sbpack>

To ease installation and use, we have created a [`pixi`](https://pixi.sh) environment named `cavatica` that includes `sbpack` and its dependencies.
This is defined in the `pixi.toml` file in the root of the repository.
To use `sbpack`, within this environment, prefix your command with `pixi run -e cavatica` (e.g. `pixi run -e cavatica sbpack_nf -h`).
Alternatively, you can launch a shell with the environment activated by running `pixi shell -e cavatica`, and then run `sbpack` command without the prefix.

### Creating and updating the `sb_nextflow_schema.yaml` file

The `sb_nextflow_schema.yaml` file is a configuration file that defines the Nextflow schema for the Cavatica port.
This file can be generated or updated with the following command:

```bash
./cavatica-build.sh
```

This will use the existing file as a starting point in order to preserve any customizations.
If you want to start fresh, you can delete the existing `sb_nextflow_schema.yaml` file and run the command again.

#### Schema customizations

The `sb_nextflow_schema.yaml` file created by the `sbpack_nf` command will not automatically include all of the customizations that we need for the Cavatica port. Below is a (partial) list of some of the changes that were made to prepare the file for use on Cavatica:

**Modified required parameters to remove the null type**

This seems to be the way to designate a parameter as required in Cavatica. For example, the `input` parameter is required, so it is changed to:

```yaml
type: File
```

instead of the original:

```yaml
type:
  - "null"
  - File
```

**Updated the list of profiles**

In the `../nextflow.config`, add `cavatica` to minor the `docker` profile for now.

**Added a customized outputs block**

Fill in the correct path for the output directory from the `--outdir` parameter:

```yaml
outputs:
  - id: nf_publishdir
    label: Publish Directory
    outputBinding:
      glob: $(inputs.outdir)
    type: Directory
```

**Add default values to options**

Using the `default:` property (which is distinct from the `sbg:toolDefaultValue:` property that is only used for documentation):
- Set default value for the `--outdir` to `riboseq_out` to avoid errors if this is left blank
- Set the default `-profile` to `cavatica`

### Pushing the workflow to Cavatica

To push the workflow to Cavatica, use:

```bash
./cavatica-build.sh push
```

This will upload the workflow definition to the Cavatica platform using the configuration in `sb_nextflow_schema.yaml`.

### Project structure

- `cavatica-build.sh`: Main script for building and pushing the workflow
- `sb_doc.md`: User documentation for the Cavatica app
- `sb_exclude.txt`: Files and directories to exclude when packaging the workflow
- `sb_nextflow_schema.yaml`: Cavatica-specific schema definition (generated)
- `README.md`: This developer documentation

### Requirements

- `pixi` package manager
- Access to Cavatica platform with appropriate permissions
- Configured Cavatica credentials

For more information about nf-core/riboseq, visit the [official documentation](https://nf-co.re/riboseq).
