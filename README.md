# fix-orchestra-quickfix

![](FIXorchestraLogo.png)

This project contains integrations between FIX Orchestra and QuickFIX.

* FIX Orchestra is intended to provide a standard and some reference implementation for *machine readable rules of engagement* between counterparties. 

* QuickFIX is a popular, open-source FIX engine. It has been implemented or ported to several programming languages, including C++, Java, .NET, and golang.

The code is based on prior work by the FTC, see [fix-orchestra-quickfix](https://github.com/FIXTradingCommunity/fix-orchestra-quickfix). Accordingly the Apache 2.0 license is applicable.

It was agreed that the code be moved to this repository for the following reasons :
* to establish curation of the code base and tools for easier customisation of QuickFIX/J for specific Rules of Engagement
* the code generation is coupled to the QuickFIX/J implementation therefore its "reason to change" is when the QuickFIX/J implementation changes

## Modules

### quickfixj-orchestra

The parent module is implemented to serve as a parent for potential future QuickFIX/J work based on FIX Orchestra. 
Two modules from the original FIX Trading Community [fix-orchestra-quickfix](https://github.com/FIXTradingCommunity/fix-orchestra-quickfix) project are not included in this build
as they would introduce a cyclic dependency with the QuickFIX/J project. These modules could be implemented in a 
separate repository in the future but use `quickfixj-orchestra` as a parent pom. 

### quickfixj-from-fix-orchestra-repository

This module provides tools to generate QuickFIX artefacts from an Orchestra repository file. 

This includes :
* QuickFIX Dictionary generation that can be consumed by the C++, Java and .NET versions. Although the QuickFIX data dictionary is not as richly featured as Orchestra, it is hoped that this utility will help with Orchestra adoption. 
* Generation of Field and Message classes for QuickFIX/J directly from an Orchestra file.
* Mvn plugins to facilitate the above

## References

[Orchestra specifications](https://github.com/FIXTradingCommunity/fix-orchestra-spec) specifications for Orchestra in GitHub.

[Orchestrations](https://github.com/FIXTradingCommunity/orchestrations) public Orchestra files for service offerings

[FIX Standards](https://www.fixtrading.org/standards/) normative standards documents  

## License
© Copyright 2016-2020 FIX Protocol Limited

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

### Participation

Issues may be entered here in GitHub or in a discussion forum on the [FIX Trading Community site](http://www.fixtradingcommunity.org/). In GitHub, anyone may enter issues or pull requests for the next release candidate. 

### Data Files
Data files in this project under `test/resources` are strictly for testing and to serve as examples for format. They are non-normative for FIX standards and may not be up to date.

