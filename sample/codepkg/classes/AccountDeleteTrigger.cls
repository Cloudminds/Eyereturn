public with sharing class AccountDeleteTrigger {

    public string actId{get;set;}
    
    public AccountDeleteTrigger(ApexPages.StandardController ctrl){
        actId=ctrl.getId();
        
        
    }
    
    public pagereference DeleteAccount(){
        Set<Id> setUserRole = GetAllAndAboveSalesManagerRoleId();
        if ((Userinfo.getUserRoleId() != null && setUserRole.contains(Userinfo.getUserRoleId()))) {
        
            List<Account> lstAc=[select Id,Adserving_Sales_Rep__c,Analyst__c,
            eyedemand_Sales_Rep__c,Name,Org_ID__c from Account where id=:actId];
            
            string error=CheckAccountBeforeDelete(lstAc);
            if(string.isNotBlank(error)){
                ApexPages.AddMessage(new ApexPages.Message(ApexPages.Severity.Error,error));
                return null; 
            }else{
                if(lstAc[0].Org_ID__c!=null){
                   Account acc=new Account(id=actId);
                   acc.Is_Deleted__c=true;
                   update acc;
                   ApexPages.AddMessage(new ApexPages.Message(ApexPages.Severity.Error,'Org Id is exist with associated accout'));
                   return null;  
                }
                //Delete Account
                delete [select id  from Account where id=:actId];

                PageReference acctPage = new PageReference('/001/o');
                acctPage.setRedirect(true);
                return acctPage; 
                
            }
        } 
        else{
            ApexPages.AddMessage(new ApexPages.Message(ApexPages.Severity.Error,'You do not have the permission to delete an account. User Role must be Sales Manager or above.'));
            return null;
        }
        return null;

    }
    
    public pagereference GoBack(){
       PageReference acctPage = new PageReference('/' + actId);
       acctPage.setRedirect(true);
       return acctPage; 
    }
    public set < Id > GetAllAndAboveSalesManagerRoleId() {
        Set < Id > allSMRoleIds = new Set < Id > ();
        // Select all SalesManager roles
        List < UserRole > lstUserRole = [Select Name, Id, ParentRoleId From UserRole
            where Name like '%sales manager%'];

        for (UserRole ul: lstUserRole) {
            allSMRoleIds.add(ul.id);
        }

        allSMRoleIds.addAll(GetAllParentRoleIds(allSMRoleIds));
        
        // Add Billing role for testing
        allSMRoleIds.add('00Ei0000000cnjR');
        
        return allSMRoleIds;
    }

    private Set < ID > GetAllParentRoleIds(Set <ID> roleIds) {
        Set < ID > parentRoleIds = new Set < ID > ();
        List < UserRole > roles = [select ParentRoleId, Name, Id from UserRole where
                                         Id IN: roleIds AND ParentRoleID != null];
        
        // Get all of the parent roles
        for (UserRole role: roles) {
            parentRoleIds.add(role.ParentRoleId);
        }
        
        // Fetch parents of the parent roles
        if (parentRoleIds.size() > 0) {
            parentRoleIds.addAll(GetAllParentRoleIds(parentRoleIds));
        }

        return parentRoleIds;
    }

    public string CheckAccountBeforeDelete(List < Account > lstAccount) {
        Employee__c unassignedEmp = [select id, name from Employee__c where name like '%UNASSIGNED%'];
        
        // Get account IDs
        Set<Id> accIds = new Set<Id>();
        for (Account acc : lstAccount) {
            accIds.add(acc.id);
        }

        // Get related objects
        // Opps
        Map<Id, Integer> oppCountMap = new Map<Id, Integer>();
        for (AggregateResult aggRes : [
              SELECT AccountId, COUNT(id) num
              FROM Opportunity
              WHERE AccountId in :accIds
              GROUP BY AccountId
        ]) {
            Id AccountId = (Id) aggRes.get('AccountId');
            Integer num = (Integer) aggRes.get('num');
            oppCountMap.put(AccountId, num);
        }
        
        // Contacts
        Map<Id, Integer> contactCountMap = new Map<Id, Integer>();
        for (AggregateResult aggRes : [
              SELECT AccountId, COUNT(id) num
              FROM Contact
              WHERE AccountId in :accIds
              GROUP BY AccountId
        ]) {
            Id AccountId = (Id) aggRes.get('AccountId');
            Integer num = (Integer) aggRes.get('num');
            contactCountMap.put(AccountId, num);
        }
        
        // Brands
        Map<Id, Integer> brandCountMap = new Map<Id, Integer>();
        for (AggregateResult aggRes : [
              SELECT Account__c, COUNT(id) num
              FROM Account_Brand_Junction__c
              WHERE Account__c in :accIds
              GROUP BY Account__c
        ]) {
            Id AccountId = (Id) aggRes.get('Account__c');
            Integer num = (Integer) aggRes.get('num');
            brandCountMap.put(AccountId, num);
        }
        
        String error = '';
        for (Account acc: lstAccount) {
            
            // Check if any Opportunities exist
            if (oppCountMap.containsKey(acc.Id) && oppCountMap.get(acc.Id) > 0) {
                error += '<li>' + oppCountMap.get(acc.Id) + ' Opportunity(ies)</li>';
            }
            
            // Check if any Employees exist
            if (acc.Adserving_Sales_Rep__c != null && acc.Adserving_Sales_Rep__c != unassignedEmp.Id) {
                error += '<li>Adserving sales rep</li>';
            }
            if (acc.Analyst__c != null && acc.Analyst__c != unassignedEmp.Id) {
                error += '<li>Analyst</li>';
            }
            if (acc.eyedemand_Sales_Rep__c != null && acc.eyedemand_Sales_Rep__c != unassignedEmp.Id) {
                error += '<li>Eyedemand sales rep</li>';
            }
            
            // Check if any Contacts exist
            if (contactCountMap.containsKey(acc.Id) && contactCountMap.get(acc.Id) > 0) {
                error += '<li>' + contactCountMap.get(acc.Id) + ' Contact(s)</li>';
            }
            
            // Check if any brands exist
            if (brandCountMap.containsKey(acc.Id) && brandCountMap.get(acc.Id) > 0) {
                error += '<li>' + brandCountMap.get(acc.Id) + ' Brand(s)</li>';
            }

            if (error.length() > 0) {
                error = 'The Account you are trying to delete contains the following related objects that must be removed first: <ul>' + error + '</ul>';
                //acc.addError(error, false);
            }
        }
        return error;
    }
}