use serde_json::Value;
use std::error::Error;

/// Parse YAML string to JSON string
pub fn parse_yaml_to_json(yaml_str: &str) -> Result<String, Box<dyn Error>> {
    // Parse YAML to serde_json::Value
    let value: Value = serde_yaml::from_str(yaml_str)?;

    // Convert to JSON string
    let json_str = serde_json::to_string(&value)?;

    Ok(json_str)
}

/// Encode JSON string to YAML string
pub fn encode_json_to_yaml(json_str: &str, block_style: bool) -> Result<String, Box<dyn Error>> {
    // Parse JSON to serde_json::Value
    let value: Value = serde_json::from_str(json_str)?;

    // Convert to YAML string with appropriate style
    let yaml_str = if block_style {
        // Use block style for better readability with nested structures
        serde_yaml::to_string(&value)?
    } else {
        // Use flow style for compact representation
        let mut serializer = serde_yaml::Serializer::new(Vec::new());
        serializer.formatter_mut().set_canonical(true);
        value.serialize(&mut serializer)?;
        String::from_utf8(serializer.into_inner())?
    };

    Ok(yaml_str)
}

/// Check if input is valid YAML
pub fn validate_yaml(yaml_str: &str) -> Result<(), Box<dyn Error>> {
    let _: Value = serde_yaml::from_str(yaml_str)?;
    Ok(())
}

/// Check if input is valid JSON
pub fn validate_json(json_str: &str) -> Result<(), Box<dyn Error>> {
    let _: Value = serde_json::from_str(json_str)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_yaml_to_json() {
        let yaml = r#"
        key: value
        nested:
          inner: 42
          array:
            - item1
            - item2
        "#;

        let result = parse_yaml_to_json(yaml).unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();

        assert_eq!(parsed["key"], "value");
        assert_eq!(parsed["nested"]["inner"], 42);
        assert_eq!(parsed["nested"]["array"][0], "item1");
        assert_eq!(parsed["nested"]["array"][1], "item2");
    }

    #[test]
    fn test_encode_json_to_yaml() {
        let json = r#"
        {
            "key": "value",
            "nested": {
                "inner": 42,
                "array": ["item1", "item2"]
            }
        }
        "#;

        let result = encode_json_to_yaml(json, true).unwrap();

        // Check that resulting YAML can be parsed back
        let parsed: Value = serde_yaml::from_str(&result).unwrap();

        assert_eq!(parsed["key"], "value");
        assert_eq!(parsed["nested"]["inner"], 42);
        assert_eq!(parsed["nested"]["array"][0], "item1");
        assert_eq!(parsed["nested"]["array"][1], "item2");
    }

    #[test]
    fn test_invalid_yaml() {
        let invalid_yaml = r#"
        key: : invalid
        -broken: structure
        "#;

        let result = parse_yaml_to_json(invalid_yaml);
        assert!(result.is_err());
    }

    #[test]
    fn test_invalid_json() {
        let invalid_json = r#"
        {
            "key": "value",
            invalid_structure
        }
        "#;

        let result = encode_json_to_yaml(invalid_json, true);
        assert!(result.is_err());
    }
}
