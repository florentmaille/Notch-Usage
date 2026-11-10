#!/usr/bin/env bash
# Préversion non notarisée, de bout en bout : scripts/release-preview.sh <version> [--yes]
#   ex. scripts/release-preview.sh 0.6.1
# Prérequis : sur main, propre et à jour ; gh connecté ; xcodegen ; notes rédigées dans
# docs/release-notes/<version>-preview.md avec le marqueur __SHA256__ à la place du checksum.
# Étapes : branche release/<version>-preview, version et build (+1), archive, zip, checksum dans les notes,
# une PR mergée après la CI verte et confirmation, release GitHub en préversion, zip téléchargé vérifié, cask du tap mis à jour.
# DRY_RUN=1 : essai à blanc depuis n'importe quelle branche ; construit le zip et affiche le checksum, puis
# remet les fichiers et la branche d'origine, sans rien committer ni pousser.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: release-preview.sh <version> [--yes]}"
YES="${2:-}"
TAG="v$VERSION-preview"
NAME="$VERSION-preview"
NOTES="docs/release-notes/$NAME.md"
BRANCH="release/$NAME"
ZIP="build/release/NotchUsage-$NAME.zip"
APP="build/NotchUsage.xcarchive/Products/Applications/NotchUsage.app"
REPO="florentmaille/Notch-Usage"
TAP="florentmaille/homebrew-tap"

fail() { echo "✗ $*" >&2; exit 1; }
step() { echo; echo "→ $*"; }

DRY="${DRY_RUN:-}"
START_BRANCH="$(git branch --show-current)"

step "Vérifications"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "version attendue au format 1.2.3"
if [[ "$DRY" != "1" ]]; then
  [[ "$START_BRANCH" == "main" ]] || fail "à lancer depuis main"
  [[ -z "$(git status --porcelain)" ]] || fail "copie de travail non propre"
  git fetch -q origin
  [[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || fail "main n'est pas à jour avec origin/main"
fi
[[ -f "$NOTES" ]] || fail "notes absentes : $NOTES"
grep -q "__SHA256__" "$NOTES" || fail "marqueur __SHA256__ absent des notes"
! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || fail "le tag $TAG existe déjà"
command -v gh >/dev/null && command -v xcodegen >/dev/null || fail "gh et xcodegen sont requis"

BUILD=$(( $(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" App/NotchUsage/Resources/Info.plist) + 1 ))
echo "Version $VERSION, build $BUILD, tag $TAG"

step "Branche et version"
[[ "$DRY" == "1" ]] || git checkout -q -b "$BRANCH"
sed -i '' -E "s/(CFBundleShortVersionString: )\"[^\"]+\"/\1\"$VERSION\"/; s/(CFBundleVersion: )\"[^\"]+\"/\1\"$BUILD\"/" project.yml
/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $VERSION" -c "Set CFBundleVersion $BUILD" App/NotchUsage/Resources/Info.plist

step "Archive et zip"
scripts/build-app.sh build/NotchUsage.xcarchive
[[ "$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")" == "$VERSION" ]] || fail "version de l'archive inattendue"
mkdir -p build/release
rm -f "$ZIP" "$ZIP.sha256"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')
echo "$SHA  $(basename "$ZIP")" > "$ZIP.sha256"
echo "SHA-256 : $SHA"

if [[ "$DRY" == "1" ]]; then
  git checkout -q -- project.yml App/NotchUsage/Resources/Info.plist
  echo; echo "DRY_RUN : zip $ZIP construit, rien n'a été committé ni poussé (branche $START_BRANCH)."
  exit 0
fi
sed -i '' "s/__SHA256__/$SHA/" "$NOTES"

step "Commit et PR"
git add project.yml App/NotchUsage/Resources/Info.plist "$NOTES"
git commit -q -m "release: $NAME

Version $VERSION (build $BUILD), release notes and zip checksum."
git push -q -u origin "$BRANCH"
PR_URL=$(gh pr create --base main --head "$BRANCH" --title "Release $NAME" \
  --body "Version $VERSION (build $BUILD). Release notes: \`$NOTES\`, SHA-256 of the zip included.")
echo "$PR_URL"
PR_NUMBER="${PR_URL##*/}"
# La constitution exige une CI verte avant le merge : on attend les vérifications de la PR.
step "CI de la PR"
sleep 10
gh pr checks "$PR_NUMBER" --watch --fail-fast || fail "CI en échec : la PR reste ouverte"
if [[ "$YES" != "--yes" ]]; then
  read -r -p "Merger $PR_URL et publier $TAG ? [y/N] " answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] || fail "arrêt avant le merge : la PR reste ouverte"
fi
gh pr merge "$PR_NUMBER" --merge --subject "Merge #$PR_NUMBER: release $NAME"
git checkout -q main
git pull -q
git branch -q -d "$BRANCH"
git push -q origin --delete "$BRANCH"

step "Release GitHub"
gh release create "$TAG" --repo "$REPO" --target main --prerelease --title "Notch Usage $NAME" \
  --notes-file "$NOTES" "$ZIP" "$ZIP.sha256"

step "Vérification du zip publié"
TMP=$(mktemp -d)
curl -sfL -o "$TMP/zip" "https://github.com/$REPO/releases/download/$TAG/$(basename "$ZIP")"
[[ "$(shasum -a 256 "$TMP/zip" | awk '{print $1}')" == "$SHA" ]] || fail "checksum du zip publié différent"
rm -rf "$TMP"
echo "Checksum identique"

step "Cask Homebrew"
sed -e "s/__VERSION__/$NAME/g" -e "s/__SHA256__/$SHA/g" scripts/cask/notch-usage.rb.template > build/release/notch-usage.rb
CASK_SHA=$(gh api "repos/$TAP/contents/Casks/notch-usage.rb" -q .sha)
gh api -X PUT "repos/$TAP/contents/Casks/notch-usage.rb" -f message="notch-usage $NAME" \
  -f content="$(base64 -i build/release/notch-usage.rb)" -f sha="$CASK_SHA" -q .commit.sha >/dev/null
gh api "repos/$TAP/contents/Casks/notch-usage.rb" -q .content | base64 -d | grep -q "version \"$NAME\"" || fail "cask non mis à jour"

step "Nettoyage"
find build/release -name 'NotchUsage-*.zip*' ! -name "NotchUsage-$NAME.zip*" -delete

echo
echo "✓ $TAG publiée : https://github.com/$REPO/releases/tag/$TAG"
echo "  Mise à jour : Réglages → Rechercher les mises à jour, ou brew update && brew upgrade --cask notch-usage"
