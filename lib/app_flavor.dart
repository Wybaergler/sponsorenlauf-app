enum AppFlavor { dev, prod }

AppFlavor currentFlavor() {
  const f = String.fromEnvironment('FLAVOR', defaultValue: 'prod');
  return f == 'dev' ? AppFlavor.dev : AppFlavor.prod;
}