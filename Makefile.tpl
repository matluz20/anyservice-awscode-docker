# used for test purposes
# fill-in required variables and rename to "Makefile"

export SCRIPTS_DIR=./scripts
export AWS_PROFILE=
export AWS_DEFAULT_REGION=eu-west-3
export AWS_ASSUME_ROLE=
export CODEBUILD_PROJECT_NAME=
export CODEBUILD_S3_BUCKET=
export CODEBUILD_S3_ARCHIVE_KEY=some/path/to/code.zip
export CODEBUILD_S3_RESULT_PATH=some/path/to/codebuild-results

start-build:
	$${SCRIPTS_DIR}/start-build --buildspec-override tests/buildspec.yml

stop-build:
	$${SCRIPTS_DIR}/stop-build --buildspec-override tests/buildspec.yml

.PHONY: start-build
