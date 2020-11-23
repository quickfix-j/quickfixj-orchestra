# fix-orchestra-quickfix

![](FIXorchestraLogo.png)

This project contains integrations between FIX Orchestra and QuickFIX.

* FIX Orchestra is intended to provide a standard and some reference implementation for *machine readable rules of engagement* between counterparties. 

* QuickFIX is a popular, open-source FIX engine. It has been implemented or ported to several programming languages, including C++, Java, .NET, and golang.

## Modules

Some models in this project are intended to be operational while others are proofs of concept.

### repository-quickfix

This module generates a QuickFIX data dictionary from an Orchestra file. The format can be consumed by the C++, Java and .NET versions. Additionally, the module generates message classes for QuickFIX/J directly from an Orchestra file. Although the QuickFIX data dictionary format is not as richly featured as Orchestra, it is hoped that this utility will help with Orchestra adoption. 

### model-quickfix
This module generates code that is conformant to the QuickFIX/J API for validating and populating messages. It is dependent on `repository-quickfix`.

### session-quickfix
A demonstration of session configuration for QuickFIX open-source FIX engine. It consumes an XML file in the `interfaces` schema.

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

