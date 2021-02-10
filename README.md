# A set of scripts for maven central migration

*Run this script at your own risk.*

- download_artifacts.sh
- complete_pom.rb
- sign_and_bundle.sh
- upload_to_sonatype.sh
- sync_to_maven_central.sh

## Usage

### download_artifacts.sh

Download all available artifacts or specified artifacts from bintray/jcenter.

```bash
./download_artifacts.sh jcenter <group id> <artifact id> [version]
```

e.g. `./download_artifacts.sh jcenter io.github.jmatsu`

```
maven/io
   |-- github
   |    |-- jmatsu
   |    |    |-- example1
   |    |    |    |-- 1.1.1
   |    |    |    |    |-- example1-1.1.1-javadoc.jar
   |    |    |    |    |-- example1-1.1.1-sources.jar
   |    |    |    |    |-- example1-1.1.1.jar
   |    |    |    |    |-- example1-1.1.1.pom
   |    |    |    |-- maven-metadata.xml
   |    |    |-- example12
```

### complete_pom.rb

Substitute several information to a pom.xml to satisfy Maven Central's requirements.

```bash
cp com.example:example.yml <group id>:<artifact id>.yml
# and tweak <group id>:<artifact id>.yml
./complete_pom.rb <group id> <artifact id> [version]
```

### sign_and_bundle.sh

Sign artifacts and bundle them into single jar file.

```bash
echo "$passphrase" | ./sign_and_bundle.sh <key id> <group id> [artifact id] [version]
# or 
export SIGNING_PASSPHRASE=...
./sign_and_bundle.sh <key id> <group id> [artifact id] [version]
```

e.g. `./sign_and_bundle.sh ABCDEF io.github.jmatsu exmaple1 1.1.1`

```
maven/io
   |-- github
   |    |-- jmatsu
   |    |    |-- example1
   |    |    |    |-- 1.1.1
   |    |    |    |    |-- example1-1.1.1-bundle.jar
   |    |    |    |    |-- example1-1.1.1-javadoc.jar
   |    |    |    |    |-- example1-1.1.1-javadoc.jar.asc
   |    |    |    |    |-- example1-1.1.1-sources.jar
   |    |    |    |    |-- example1-1.1.1-sources.jar.asc
   |    |    |    |    |-- example1-1.1.1.jar
   |    |    |    |    |-- example1-1.1.1.jar.asc
   |    |    |    |    |-- example1-1.1.1.pom
   |    |    |    |    |-- example1-1.1.1.pom.asc
   |    |    |    |-- maven-metadata.xml
   |    |    |-- example12
```

### upload_to_sonatype.sh

Upload bundled jar files to sonatype staging.

```bash
export NEXUS_USERNAME=...
export NEXUS_PASSWORD=...
./upload_to_sonatype.sh <group id> [artifact id] [version]
```

### sync_to_maven_central.sh

Release staging repositories i.e. Sync to Maven Central.

> Dropping repositories is not supported.

```bash
export NEXUS_USERNAME=...
export NEXUS_PASSWORD=...
./sync_to_maven_central.sh <group id> [artifact id] [version]
```

## Tips

### Upload to S3

```
% aws s3 sync "${WORKING_DIRECTORY-maven}" "s3://<bucket_name>/<where you'd like to put into>"
```
