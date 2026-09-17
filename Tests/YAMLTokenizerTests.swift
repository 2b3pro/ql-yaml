import Foundation

@main
struct TestRunner {
    static func main() {
        print("🧪 Running YAML Tokenizer & Validator Tests...")
        
        let tokenizer = YAMLTokenizer()
        let validator = YAMLValidator()
        let renderer = YAMLHTMLRenderer()
        
        // Test 1: Simple YAML
        let yaml1 = """
        name: "My Application"
        version: 1.2.3
        debug: true
        port: 8080
        timeout: 30.5
        nullValue: null
        """
        let analysis1 = tokenizer.tokenizeAndAnalyze(yaml1)
        assert(analysis1.isValid, "Simple YAML should be valid")
        assert(analysis1.totalKeys == 6, "Expected 6 keys, got \(analysis1.totalKeys)")
        print("✅ Test 1 Passed: Simple YAML tokenized correctly (\(analysis1.totalKeys) keys)")
        
        // Test 2: Tab character error detection
        let yamlWithTab = "parent:\n\tchild: value\n"
        let analysis2 = tokenizer.tokenizeAndAnalyze(yamlWithTab)
        assert(!analysis2.isValid, "YAML with tabs in indentation must be flagged as invalid")
        assert(analysis2.diagnostics.contains { $0.message.contains("tab") }, "Expected tab diagnostic")
        print("✅ Test 2 Passed: Tab indentation detected and flagged as error")
        
        // Test 3: Unclosed quote detection
        let yamlUnclosedQuote = "title: \"unclosed string\nauthor: John\n"
        let diags3 = validator.validate(yamlUnclosedQuote)
        assert(diags3.contains { $0.message.contains("Unclosed") }, "Expected unclosed quote error")
        print("✅ Test 3 Passed: Unclosed quote detected")
        
        // Test 4: Duplicate key detection
        let yamlDupKey = """
        server:
          host: localhost
          port: 80
          port: 8080
        """
        let diags4 = validator.validate(yamlDupKey)
        assert(diags4.contains { $0.message.contains("Duplicate key") }, "Expected duplicate key warning")
        print("✅ Test 4 Passed: Duplicate key warning detected")
        
        // Test 5: Code folding hierarchy
        let yamlFolding = """
        app:
          server:
            port: 8080
            host: 0.0.0.0
          database:
            url: postgres://localhost
        other:
          enabled: false
        """
        let analysis5 = tokenizer.tokenizeAndAnalyze(yamlFolding)
        let appToken = analysis5.lines.first { $0.lineNumber == 1 }
        assert(appToken?.isFoldableHeader == true, "Line 1 (app:) should be foldable")
        assert(appToken?.foldEndLine == 6, "Line 1 should fold to line 6, got \(String(describing: appToken?.foldEndLine))")
        print("✅ Test 5 Passed: Code folding ranges calculated correctly")
        
        // Test 6: HTML Rendering
        let html = renderer.render(yamlString: yaml1, fileName: "test.yaml", fileSizeBytes: 120)
        assert(html.contains("<!DOCTYPE html>"), "HTML should contain doctype")
        assert(html.contains("hl-key"), "HTML should contain highlighted keys")
        assert(html.contains("hl-number"), "HTML should contain highlighted numbers")
        assert(html.contains("test.yaml"), "HTML should contain filename")
        print("✅ Test 6 Passed: HTML generated with complete syntax spans and header")
        
        // Test 7: Kubernetes Multi-document with Anchors & Block Scalars
        let k8sYaml = """
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: nginx-deployment
          labels:
            app: nginx
        spec:
          replicas: 3
          template:
            spec:
              containers:
              - name: nginx
                image: nginx:1.14.2
                ports:
                - containerPort: 80
        ---
        apiVersion: v1
        kind: Service
        metadata:
          name: nginx-service
        spec:
          type: NodePort
          ports:
          - port: 80
            targetPort: 80
            nodePort: 30007
        """
        let analysisK8s = tokenizer.tokenizeAndAnalyze(k8sYaml)
        assert(analysisK8s.isValid, "Kubernetes manifest should be valid")
        assert(analysisK8s.documentCount == 2, "Expected 2 documents, got \(analysisK8s.documentCount)")
        print("✅ Test 7 Passed: Multi-document Kubernetes manifest parsed (\(analysisK8s.documentCount) docs)")
        
        // Test 8: YAML Anchors and Aliases
        let anchorYaml = """
        defaults: &default_settings
          adapter: postgres
          host: localhost
          timeout: 5000
        
        development:
          database: dev_db
          <<: *default_settings
        
        production:
          database: prod_db
          <<: *default_settings
        """
        let analysisAnchor = tokenizer.tokenizeAndAnalyze(anchorYaml)
        assert(analysisAnchor.isValid, "Anchor YAML should be valid")
        let anchorHtml = renderer.render(yamlString: anchorYaml, fileName: "database.yml")
        assert(anchorHtml.contains("hl-anchor"), "Expected anchor highlight")
        assert(anchorHtml.contains("hl-alias"), "Expected alias highlight")
        // Test 9: Soft wrap verification
        let longLineYaml = "description: " + String(repeating: "This is a very long line of text that should soft wrap properly in raw mode without horizontal scrollbar. ", count: 5)
        let wrapHtml = renderer.render(yamlString: longLineYaml, fileName: "test_wrap.yaml", fileSizeBytes: 500)
        assert(wrapHtml.contains("id=\"btn-wrap\""), "Must contain wrap button in toolbar")
        assert(wrapHtml.contains("#raw-container.wrap"), "Must contain #raw-container.wrap CSS")
        assert(wrapHtml.contains("toggleWrap()"), "Must contain toggleWrap() JS function")
        assert(wrapHtml.contains("white-space: pre-wrap;"), "Must contain pre-wrap rule")
        print("✅ Test 9 Passed: Soft wrap button, CSS pre-wrap, and toggle function verified")
        
        print("🎉 All 9 Unit Tests Passed Successfully!")
    }
}
