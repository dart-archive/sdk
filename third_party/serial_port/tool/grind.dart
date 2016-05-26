import 'package:grinder/grinder.dart';
import 'dart:io';


main(args) => grind(args);

@Task('Compile extension as native library')
compile() => new PubApp.local('ccompile:ccompile').run(['lib/src/serial_port.yaml']);

@Task('Run tests')
test() => new TestRunner().test(files: "test/serial_port_test.dart");

@Task('Calculate test coverage')
coverage() =>
  new PubApp.local('dart_coveralls').run(['report', '--exclude-test-files', 'test/serial_port_test.dart',
                                  r'--token $SERIAL_PORT_COVERALLS_TOKEN']);

@Task("Analyze lib source code")
analyse() => Analyzer.analyzeFiles(["lib/serial_port.dart", "lib/cli.dart"], fatalWarnings: true);

@Task('Generate dartdoc')
doc() => new PubApp.local('dartdoc');

@DefaultTask('Combine tasks for continous integration')
@Depends('compile', 'test', 'analyse')
make(){
  // Nothing to declare here
}
