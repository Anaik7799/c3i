const fs = require('fs');
const path = require('path');
const yaml = require(path.join(process.cwd(), '.agents/node_modules/js-yaml'));

const auditGenotype = (filePath) => {
    console.log(`PROBING YAML GENOTYPE: ${filePath}`);
    try {
        const file = fs.readFileSync(filePath, 'utf8');
        const data = yaml.load(file);
        console.log("RESULT: SYNTAX VALID");

        const violations = [];
        if (data.services) {
            Object.entries(data.services).forEach(([name, service]) => {
                if (service.image && !service.image.startsWith('localhost/')) {
                    violations.append(`SC-CNT-010 VIOLATION: Service [${name}] uses non-local image [${service.image}]`);
                }
            });
        }

        if (violations.length === 0) {
            console.log("RESULT: SEMANTICALLY COMPLIANT (SIL4)");
            process.exit(0);
        } else {
            console.log("RESULT: SEMANTIC VIOLATIONS DETECTED");
            violations.forEach(v => console.log(`  !! ${v}`));
            process.exit(1);
        }
    } catch (e) {
        console.log(`RESULT: YAML CORRUPT: ${e.message}`);
        process.exit(1);
    }
};

const args = process.argv.slice(2);
if (args.length > 0) {
    auditGenotype(args[0]);
} else {
    console.log("YAML Oracle ready.");
    process.exit(0);
}
