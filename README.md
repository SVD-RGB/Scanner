### Contributing
Ensure proper byte order marks (BOM) are maintained when utilizing a PowerShell linter with the following steps:

```shell
pip3 install pre-commit
pre-commit install
pre-commit install-hooks
```

By following these instructions, pre-commit hooks will be activated, automatically resolving any byte order mark issues within your PowerShell files. Additionally, these hooks will be triggered prior to committing code to your GitHub repository, ensuring consistent formatting and adherence to best practices.

You can also trigger pre-commit hooks manually by

```shell
pre-commit run --all-files
```
