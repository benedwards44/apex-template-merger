# apex-template-merging
Custom Apex utility for merging strings containing merge fields and replacing with values

This utility provides a way to pass a string containing merge fields using `{{ field_name }}` syntax, and getting the SObject record value.

Eg.
```
String myTemplate = 'Hey {{ FirstName }}, your email address is {{ Email }} and account name is {{ Account.Name }}';

String myResult = MergeFieldUtility.replaceMergeFieldsWithValues (
  myTemplate, // The string to merge
  '0032800000YWeRQ' // The record ID
);

system.debug(myResult);

###[DEBUG]: Hey Ben, your email address is ben@edwards.nz and account name is Edwards Enterprises
```

<br/>
<a href="https://githubsfdeploy.herokuapp.com?owner=benedwards44&repo=apex-template-merger&ref=master"></a>
  <img alt="Deploy to Salesforce"
       src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png">
</a>