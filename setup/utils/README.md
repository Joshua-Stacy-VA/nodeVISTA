JS-based setup - invoked AFTER node is installed.

## Parameter Service
The `updateNodeVISTAParameters.js` module contains a script that uses the VDP [ParameterService](https://github.com/vistadataproject/nonClinicalRPCs/wiki/Parameter-Service)
to update and customize the nodeVISTA instance parameter set beyond what is setup in the stock VistA.

The script depends on the `nodeVISTAParameters.json` file for parameter entity and values to set.

The 'nodeVISTAParameters' JSON should hold an array of JSON objects, each with the following format:

```Javascript
{
    "name": <<PARAMETER NAME>>,
    "entity": <<ENTITY TO SET>>,
    "instance": <<INSTANCE FOR THE PARAMETER>>,
    "value": <<VALUE TO SET>>
}
```

EXAMPLE:
```
{
    "name": "ORWCH COLUMNS REPORTS",
    "entity": "200-62",
    "instance": "1029",
    "value": "0,0,130,42,47,41,83,43,46,33,32,33,32,0,0,0,0,0,"
}
```

You can also add 'delete' as a command line argument to the script to delete/unset/undo all the
changes specified in the `nodeVISTAParameters.json` file.

EXAMPLE:
```Javascript
node updateNodeVISTAParameters.js delete
```

### Entity Values
The `entity` attribute can contain entity values in one of 3 formats:

1. Fileman file entry value corresponding to a valid, acceptable entity for that particular parameter (e.g. `200-62` for user with IEN of **62**).

   The utility will convert the file entry to the appropriate parameter entity code.
2. VistA entity prefix to set the value based on the current entity.  The supported values are:
    * **USR** - uses current value of DUZ
    * **DIV** - uses current value of DUZ(2)
    * **SYS** - uses system (domain)
    * **PKG** - uses the package to which the parameter belongs
3. A parameter entity code, formatted in internal (`nnn;GLO(123,`) or external (``GLO.`nnn``) format
