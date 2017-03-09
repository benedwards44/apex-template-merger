/**
* @author Ben Edwards (ben@edwards.nz)
* @date 2016-08-25
* @description Take a given string with merge fields and replace with values
**/
public class MergeFieldUtility {

    // The Pattern used for all merging. This is the {{ Field__c }} syntax.
    // You can replace this with your own merge sync (eg. <? Field__c ?> or {!Field__c}
    private static Pattern thePattern(String startPattern, String endPattern) {

        // Make sure we have a pattern
        if (String.isBlank(startPattern.trim()) || String.isBlank(endPattern.trim())) {
            throw new MergeFieldUtilityException('Start and End pattern required!');
        }

        // Regex to capture grouping
        String theRegex = '';

        // Convert the start pattern to regex
        for (String character : startPattern.split()) {
            theRegex += character == ' ' ? '' : '\\' + character;
        }

        // Add Capturing Group to regex and include first end charcter to close grouping
        theRegex += '([^'+ endPattern.trim().left(1) +'}]*)';

        // Convert the end pattern to regex
        for (String character : endPattern.split()) {
            theRegex += character == ' ' ? '' : '\\' + character;
        }

        // Replace all spaces with whitespace capturing
        theRegex = theRegex.replace(' ', '\\s');

        return Pattern.compile(theRegex);
    }

	/**
	*   @author Ben Edwards (ben@edwards.nz)
	*   @description Generate the string with the replaced values
	*   @return Returns the string with all merge fields replaced with values
	**/
    public static String replaceMergeFieldsWithValues (String stringToMerge, String recordId) {

        // Get the object name based on the recordId
        String objectName = ((Id) recordId).getSObjectType().getDescribe().getName();

        // The matcher which returns the matched fields from the given string
        Matcher theMatcher = thePattern().matcher(stringToMerge);

        // Query for the SObject and all related fields
        SObject theRecord = getRecord (stringToMerge, objectName, recordId);

        // Iterate over each match
        while (theMatcher.find()) {

            // Get the field name based on the match
            String mergeField = theMatcher.group(1).trim();

            // The following logic is a bit ugly. The idea is to support getting parent fields for the object
            // This allows to go 5 levels high. If anyone knows a better way to do this, please let me know.
            // Eg. {{ Case.Contact.Account.Name }}
            // Eg2. {{ Child__r.Parent__r.Email }}

            // Need to determine if there is a relationship in the field. This decides how many levels up to go
            List<String> objectsAndField = mergeField.split('\\.');

            // The record to get the data from
            SObject theRecordForData = theRecord;

            // If there is a relationship
            if (objectsAndField.size() > 1) {

                // Run through the list but skip the last item (the field)
                for (Integer i = 0; i < objectsAndField.size() - 1; i++) {

                    // Get the new record to draw data from
                    theRecordForData = theRecordForData.getSObject(objectsAndField[i]);
                }

                // Since we should have the correct record now we can replace the list with only it's last item (the field)
                objectsAndField = new List<String>{objectsAndField[objectsAndField.size()-1]};
            }

            // Replace the matching field name with the value
            stringToMerge = stringToMerge.replace('{{ ' + mergeField + ' }}', String.valueOf(theRecordForData.get(objectsAndField[0])));

        }

        // Return the string with all the merge fields replaced with their values, yay!
        return stringToMerge;
    }


	/**
	*   @author Ben Edwards (ben@edwards.nz)
	*   @description Do a dynamic SOQL query to get the record and required fields for the merging
	*   @return Return the SObject record
	**/
    private static SObject getRecord (String stringToMerge, String objectName, String recordId) {

        // The set of fields to query for
        Set<String> fieldsForQuery = new Set<String>();

        // The matcher which returns the matched fields from the given string
        Matcher theMatcher = thePattern('{{ ', ' }}').matcher(stringToMerge);

        // Loop through each match
        while (theMatcher.find()) {

            // Add the field name to the set
            fieldsForQuery.add(theMatcher.group(1).trim());
        }

        // Build the query. The set of fields needs to be converted to a list to use String.join()
        String theQuery = 'SELECT ' + String.join(new List<String>(fieldsForQuery), ',');
        theQuery += ' FROM ' + objectName;
        theQuery += ' WHERE Id = \'' +  recordId + '\'';

        // Execute the query and record the record
        return Database.query(theQuery);
    }

    // Custom Exceptions
    public class MergeFieldUtilityException extends Exception {}
}