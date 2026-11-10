#!/usr/bin/env bash
# Publication de bout en bout : scripts/publish.sh <version> [--stable] [--yes]
#   scripts/publish.sh 0.6.1            préversion v0.6.1-preview, non notarisée
#   scripts/publish.sh 0.6.1 --stable   version stable v0.6.1, signée Developer ID et notarisée (constitution)
# Prérequis : sur main, propre et à jour ; gh connecté ; xcodegen ; notes rédigées dans
# docs/release-notes/<nom>.md (<nom> = 0.6.1-preview ou 0.6.1) avec le marqueur __SHA256__ à la place du checksum.
# --stable demande en plus un certificat « Developer ID Application » et le profil notarytool `notchusage` :
# voir docs/release-signing.md.
# Étapes : branche release/<nom>, version et build (+1), archive, [signature, notarisation, agrafage], zip,
# checksum dans les notes, une PR mergée après la CI verte et confirmation, release GitHub, zip publié vérifié,
# cask du tap mis à jour.
# DRY_RUN=1 : essai à blanc depuis n'importe quelle branche ; construit (et signe en --stable) le zip et affiche le
# checksum, puis remet les fichiers et la branche d'origine, sans rien committer ni pousser.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: publish.sh <version> [--stable] [--yes]}"
shift
STABLE="" YES=""
for arg in "$@"; do
  case "$arg" in
    --stable) STABLE=1 ;;
    --yes) YES="--yes" ;;
    *) echo "option inconnue : $arg" >&2; exit 2 ;;
  esac
done
if [[ -n "$STABLE" ]]; then NAME="$VERSION"; else NAME="$VERSION-preview"; fi
TAG="v$NAME"
IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application}"
PROFILE="${NOTARY_PROFILE:-notchusage}"
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
if [[ -n "$STABLE" ]]; then
  security find-identity -v -p codesigning | grep -q "$IDENTITY" \
    || fail "certificat « $IDENTITY » absent du Trousseau : voir docs/release-signing.md"
  xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1 \
    || fail "profil notarytool « $PROFILE » absent : voir docs/release-signing.md"
fi

BUILD=$(( $(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" App/NotchUsage/Resources/Info.plist) + 1 ))
echo "Version $VERSION, build $BUILD, tag $TAG$([[ -n "$STABLE" ]] && echo ", stable signée et notarisée")"

step "Branche et version"
[[ "$DRY" == "1" ]] || git checkout -q -b "$BRANCH"
sed -i '' -E "s/(CFBundleShortVersionString: )\"[^\"]+\"/\1\"$VERSION\"/; s/(CFBundleVersion: )\"[^\"]+\"/\1\"$BUILD\"/" project.yml
/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $VERSION" -c "Set CFBundleVersion $BUILD" App/NotchUsage/Resources/Info.plist

step "Archive et zip"
scripts/build-app.sh build/NotchUsage.xcarchive
[[ "$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")" == "$VERSION" ]] || fail "version de l'archive inattendue"
mkdir -p build/release
rm -f "$ZIP" "$ZIP.sha256"
if [[ -n "$STABLE" ]]; then
  step "Signature, notarisation, agrafage"
  codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" \
    --entitlements App/NotchUsage/Resources/NotchUsage.entitlements "$APP"
  codesign --verify --strict --verbose=2 "$APP"
  # notarytool n'accepte pas une .app nue : on soumet un zip, puis on agrafe le ticket sur l'app.
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
  xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$APP"
  spctl --assess --type execute --verbose "$APP"
  rm -f "$ZIP"
fi
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
PRERELEASE=(--prerelease)
[[ -n "$STABLE" ]] && PRERELEASE=()
gh release create "$TAG" --repo "$REPO" --target main "${PRERELEASE[@]}" --title "Notch Usage $NAME" \
  --notes-file "$NOTES" "$ZIP" "$ZIP.sha256"

step "Vérification du zip publié"
TMP=$(mktemp -d)
curl -sfL -o "$TMP/zip" "https://github.com/$REPO/releases/download/$TAG/$(basename "$ZIP")"
[[ "$(shasum -a 256 "$TMP/zip" | awk '{print $1}')" == "$SHA" ]] || fail "checksum du zip publié différent"
rm -rf "$TMP"
echo "Checksum identique"

step "Cask Homebrew"
# Stable : l'avertissement « not notarized » du cask n'a plus lieu d'être.
CASK_FILTER='/is not notarized yet/,/^$/d'
[[ -n "$STABLE" ]] || CASK_FILTER='p;d'
sed -e "s/__VERSION__/$NAME/g" -e "s/__SHA256__/$SHA/g" scripts/cask/notch-usage.rb.template | sed "$CASK_FILTER" > build/release/notch-usage.rb
CASK_SHA=$(gh api "repos/$TAP/contents/Casks/notch-usage.rb" -q .sha)
gh api -X PUT "repos/$TAP/contents/Casks/notch-usage.rb" -f message="notch-usage $NAME" \
  -f content="$(base64 -i build/release/notch-usage.rb)" -f sha="$CASK_SHA" -q .commit.sha >/dev/null
gh api "repos/$TAP/contents/Casks/notch-usage.rb" -q .content | base64 -d | grep -q "version \"$NAME\"" || fail "cask non mis à jour"

step "Nettoyage"
find build/release -name 'NotchUsage-*.zip*' ! -name "NotchUsage-$NAME.zip*" -delete

echo
echo "✓ $TAG publiée : https://github.com/$REPO/releases/tag/$TAG"
echo "  Mise à jour : Réglages → Rechercher les mises à jour, ou brew update && brew upgrade --cask notch-usage"
