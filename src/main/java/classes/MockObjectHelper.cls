/**
 * Created by Valera on 24.10.2017.
 */

public with sharing class MockObjectHelper {

    //SINGLE MOCk OBJECT
    public class BulkMockGenerator implements HttpCalloutMock {
        Map<String, HttpCalloutMock> requests;

        public BulkMockGenerator(Map<String, HttpCalloutMock> requests) {
            this.requests = requests;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpCalloutMock mock = requests.get(req.getEndpoint().substringBefore('?'));
            if (mock != null) {
                return mock.respond(req);
            } else {
                throw new MyCustomException('HTTP callout not supported for test methods');
            }
        }
    }

    //MULTY MOCK OBJECT
    public virtual class GeneralRequestMock implements HttpCalloutMock {
        protected Integer code;
        protected String status;
        protected String bodyAsString;
        protected Map<String, String> responseHeaders;

        public GeneralRequestMock(Integer code, String status, String body,
                Map<String, String> responseHeaders) {
            this.code = code;
            this.status = status;
            this.bodyAsString = body;
            this.responseHeaders = responseHeaders;
        }

        public virtual HTTPResponse respond(HTTPRequest req) {
            HttpResponse resp = new HttpResponse();
            resp.setStatusCode(code);
            resp.setStatus(status);
            resp.setBody(bodyAsString);

            if (responseHeaders != null) {
                for (String key : responseHeaders.keySet()) {
                    resp.setHeader(key, responseHeaders.get(key));
                }
            }
            return resp;
        }
    }
}