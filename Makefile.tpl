# used for test purposes
# fill-in required variables and rename to "Makefile"

export AWS_DEFAULT_REGION=eu-west-3
export AWS_ASSUME_ROLE=
export CODEBUILD_PROJECT_NAME=
export CODEBUILD_S3_BUCKET=
export CODEBUILD_S3_ARCHIVE_KEY=some/path/to/code.zip
export CODEBUILD_S3_RESULT_PATH=some/path/to/codebuild-results

start-build:
	scripts/start-build --buildspec-override tests/buildspec.yml

.PHONY: start-build
