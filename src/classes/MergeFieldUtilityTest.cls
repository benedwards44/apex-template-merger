/**
 * @author       Tiaan Swart (tswart@deloitte.co.nz)
 * @date         2019-07-09
 * @description  MergeFieldUtilityTest
 * 
 * CHANGE LOG
 * 2019-07-09 - Initial Setup of MergeFieldUtilityTest
 **/
@IsTest
private  class MergeFieldUtilityTest {

    @IsTest
    static public void testUtil() {

        Account newAccount = new Account(Name='Edwards Enterprises');
        insert newAccount;

        Contact newContact = new Contact(FirstName='Ben', LastName='Edwards', Email='ben@edwards.nz', AccountId=newAccount.Id);
        insert newContact;

        String myTemplate = 'Hey {{ FirstName }}, your email address is {{ Email }} and account name is {{ Account.Name }}';

        String myResult = MergeFieldUtility.replaceMergeFieldsWithValues (
            myTemplate, // The string to merge
            newContact.Id // The record ID
        );

        System.assertEquals('Hey Ben, your email address is ben@edwards.nz and account name is Edwards Enterprises', myResult);

    }

}