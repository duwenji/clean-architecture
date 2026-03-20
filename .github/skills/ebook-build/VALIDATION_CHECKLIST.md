# Ebook Build Validation Checklist

## Build Execution

- [ ] Runner exits with code 0
- [ ] No unexpected interactive prompts appear
- [ ] Output directory is created or reused successfully

## Artifacts

- [ ] EPUB output exists
- [ ] AZW3 output exists or a clear warning is shown
- [ ] MOBI output exists or a clear warning is shown
- [ ] Output filenames use `projectName` as the base name

## Structural Quality

- [ ] TOC is generated
- [ ] Internal links work
- [ ] Heading hierarchy is readable
- [ ] Code blocks render correctly

## Repository-Specific Quality

- [ ] Cover file is included when `00-COVER.md` exists
- [ ] `README.md` AUTO-TOC remains valid in the source repository
- [ ] Chapter order matches numbered folders and files

## Compatibility

- [ ] Review `docs/KINDLE-COMPATIBILITY-CHECKLIST.md`
- [ ] Preview EPUB in an EPUB reader
- [ ] Validate AZW3/MOBI on the target Kindle environment
