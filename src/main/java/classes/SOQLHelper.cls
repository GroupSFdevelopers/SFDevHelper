/**
 * Created by Valera on 24.10.2017.
 */

public with sharing class SOQLHelper {
    public interface ISelectable {
        Set<Schema.SObjectField> getDefaultSObjectFields();
        Schema.SObjectType getSObjectType();
    }
    public virtual class cls_SoqlWrapperBuilder {
        public List<String> fields;
        public String sObjectName;
        public SoqlCondition QueryCondition;
        public Integer RecordsLimit;
        public String OrderExpression;

        public cls_SoqlWrapperBuilder(ISelectable selector) {
            sObjectName = selector.getSObjectType().getDescribe().getName();
            List<String> field_names = new List<String>();
            for (Schema.SObjectField sobject_field : selector.getDefaultSObjectFields()) {
                field_names.add(sobject_field.getDescribe().getName());
            }
            fields = new List<String>(field_names);
        }

        public cls_SoqlWrapperBuilder addFields(Set<String> extra_fields) {
            this.fields.addAll(extra_fields);
            return this;
        }
        public cls_FBSelectFactory.cls_SoqlWrapperBuilder addFields(Set<Schema.SObjectField> extra_fields) {
            for (Schema.SObjectField field : extra_fields) {
                this.fields.add(field.getDescribe().getName());
            }
            return this;
        }


        public cls_SoqlWrapperBuilder setRecordsLimit(Integer records_limit) {
            this.RecordsLimit = records_limit;
            return this;
        }

        public cls_SoqlWrapperBuilder setCondition(cls_FBSelectFactory.SoqlCondition condition) {
            this.QueryCondition = condition;
            return this;
        }
        public cls_SoqlWrapperBuilder orderASC(Schema.SObjectField order_field_name) {
            this.OrderExpression = order_field_name.getDescribe().getName() + ' ASC';
            return this;
        }

        public virtual string buildQuery() {

            String query = 'SELECT ' + String.join(fields, ', ') + ' FROM ' + sObjectName;
            if (queryCondition != null) {
                query += ' WHERE ' + QueryCondition.toSOQL();
            } if (this.OrderExpression != null) {
                query += ' ORDER BY ' + this.OrderExpression;
            }
            if (this.RecordsLimit != null) {
                query += ' LIMIT ' + this.RecordsLimit;
            }
            return query ;
        }
    }

    public class cls_SoqlChildQueryWrapperBuilder extends cls_SoqlWrapperBuilder {
        String ParentSObjectName;

        public cls_SoqlChildQueryWrapperBuilder(ISelectable selector, Schema.SObjectType parent_object) {
            super(selector);
            this.ParentSObjectName = parent_object.getDescribe().getName();
        }
        public override String buildQuery() {
            List<String> fields_list = new List<String>(fields);
            String query = 'SELECT ' + String.join(fields_list, ', ') + ' FROM ' + this.getRelationshipName();
            if (queryCondition != null) {
                query += ' WHERE ' + QueryCondition.toSOQL();
            }
            if (this.RecordsLimit != null) {
                query += ' LIMIT ' + this.RecordsLimit;
            }
            if (this.OrderExpression != null) {
                query += ' ORDER BY ' + this.OrderExpression;
            }
            return '(' + query + ')';

        }

        private String getRelationshipName() {
            Schema.Describesobjectresult describe_result = Schema.getGlobalDescribe().get(ParentSObjectName).getDescribe();
            for (ChildRelationship child : describe_result.getChildRelationships()) {
                if (String.valueOf(child.getChildSObject()) == this.sObjectName) {
                    return child.getRelationshipName();
                }
            }
            return ParentSObjectName;
        }


    }

    public abstract class SoqlCondition {
        public abstract String toSOQL();
    }

    public class SimpleSoqlCondition extends SoqlCondition {
        private string soql_cond;
        public SimpleSoqlCondition(Schema.SObjectField field_name, String operator, Object value) {
            this(field_name.getDescribe().getName(), operator, value);
        }
        public SimpleSoqlCondition(String field, String operator, Object value) {
            if (isCollection(value)) {
                soql_cond = field + ' ' + operator + getCollectionValue(value) ;
            } else if (value == null || Boolean.valueOf(value)) {
                soql_cond = field + ' ' + operator + value ;
            } else {
                soql_cond = field + ' ' + operator + ' \'' + value + '\'';
            }
        }
        public Boolean isCollection(Object collection) {
            Object test;
            if (collection == null) {
                return false;
            }
            try {
                test = (List<Object>) collection;
                return true;
            } catch (System.TypeException ex) {
                String message = ex.getMessage();
                return message.contains('Set<') ;
            }
            return false;
        }
        public String getCollectionValue(Object collection) {
            String collection_value = String.valueOf(collection).substringBetween('{', '}');
            List<String> collection_elements = collection_value.split(',');
            String formated_collection = String.join(collection_elements, '\',\'');
            return '(\'' + formated_collection.replaceAll('\\s+', '') + '\')';
        }
        public override String toSOQL() {
            return soql_cond;
        }
    }


    public class ComplexSoqlCondition extends SoqlCondition {
        private string soql_cond;
        public ComplexSoqlCondition(String operator, List<SoqlCondition> conds) {
            List<String> compiled_soqls = new List<String>();
            for (SoqlCondition c : conds) {
                compiled_soqls.add('(' + c.toSOQL() + ')');
            }
            soql_cond = String.join(compiled_soqls, ' ' + operator + ' ');
        }
        public override String toSOQL() {
            return soql_cond;
        }
    }

    public class ParentFieldWrapper {
        public SObject CurrentSobject;
        public Schema.SObjectField RelationField;
        public List<Schema.SObjectField> ParentFields;

        public cls_FBSelectFactory.ParentFieldWrapper(SObject sobj, Schema.SObjectField field, List<Schema.SObjectField> parent_fields) {
            this.CurrentSobject = sobj;
            this.RelationField = field;
            this.ParentFields = parent_fields;
        }

    }
}