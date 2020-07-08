#### MEMCM Policy Priority

If you have ever been in an environment with even a handful of AV Policies, or Client Settings polcies in MEMCM then you have felt the pain of clicking increase, or decrease over and over. 

In this folder you'll find a couple quick functions to simplify setting the priority of a MEMCM Antimalware Policy, or Client Settings policy. They support -Verbose, and -WhatIf. An example of using each of them is below.

```ps
Set-CMAntiMalwarePolicyPriority -Name AVPolicy1 -Priority 3
Set-CMClientSettingPriority -Name ClientSettings1 -Priority 1
```

They could be improved by adding pipeline support from the builtin Get-CM* cmdlets for the respective types.... feel free to add a pull request :)
