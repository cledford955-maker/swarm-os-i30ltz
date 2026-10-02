package services

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	wa "github.com/go-webauthn/webauthn/webauthn"
)

var (
	waInstance     *wa.WebAuthn
	waOnce         sync.Once
	waMu           sync.Mutex
	waRegSession   *wa.SessionData
	waLoginSession *wa.SessionData
	waCredentials  []storedWACredential
)

type storedWACredential struct {
	Credential wa.Credential `json:"credential"`
	RegDate    time.Time     `json:"reg_date"`
}

type waUser struct {
	creds []wa.Credential
}

func (u *waUser) WebAuthnID() []byte                         { return []byte("swarm_user1") }
func (u *waUser) WebAuthnName() string                       { return "admin" }
func (u *waUser) WebAuthnDisplayName() string                { return "Administrator" }
func (u *waUser) WebAuthnCredentials() []wa.Credential       { return u.creds }
func (u *waUser) WebAuthnIcon() string                       { return "" }

func waCredPath() string {
	return filepath.Join(lucyStateDir(), "webauthn_credentials.json")
}

func getWA() *wa.WebAuthn {
	waOnce.Do(func() {
		rpID := os.Getenv("WEBAUTHN_RP_ID")
		if rpID == "" {
			rpID = "localhost"
		}
		origins := []string{
			"http://localhost:5000",
			"http://localhost:5173",
			"http://localhost:3000",
		}
		if o := os.Getenv("WEBAUTHN_ORIGINS"); o != "" {
			origins = strings.Split(o, ",")
		}
		var err error
		waInstance, err = wa.New(&wa.Config{
			RPDisplayName: "SWARM OS",
			RPID:          rpID,
			RPOrigins:     origins,
		})
		if err != nil {
			panic("webauthn init: " + err.Error())
		}
		loadWACredentials()
	})
	return waInstance
}

func loadWACredentials() {
	data, err := os.ReadFile(waCredPath())
	if err != nil {
		return
	}
	json.Unmarshal(data, &waCredentials)
}

func saveWACredentials() {
	path := waCredPath()
	os.MkdirAll(filepath.Dir(path), 0o755)
	b, _ := json.Marshal(waCredentials)
	os.WriteFile(path, b, 0o600)
}

func currentWAUser() *waUser {
	u := &waUser{}
	for _, c := range waCredentials {
		u.creds = append(u.creds, c.Credential)
	}
	return u
}

// WAGetRegisterOptions returns credential creation options for the browser.
func WAGetRegisterOptions() (any, error) {
	instance := getWA()
	waMu.Lock()
	defer waMu.Unlock()

	creation, session, err := instance.BeginRegistration(currentWAUser())
	if err != nil {
		return nil, err
	}
	waRegSession = session
	return creation, nil
}

// WAVerifyRegister parses and verifies the attestation from the browser, stores the credential.
func WAVerifyRegister(r *http.Request) (any, error) {
	instance := getWA()
	waMu.Lock()
	defer waMu.Unlock()

	if waRegSession == nil {
		return nil, fmt.Errorf("no registration session found")
	}

	cred, err := instance.FinishRegistration(currentWAUser(), *waRegSession, r)
	if err != nil {
		return nil, err
	}
	waRegSession = nil
	waCredentials = append(waCredentials, storedWACredential{
		Credential: *cred,
		RegDate:    time.Now().UTC(),
	})
	saveWACredentials()
	return map[string]string{"status": "ok"}, nil
}

// WAGetLoginOptions returns assertion options for the browser.
func WAGetLoginOptions() (any, error) {
	instance := getWA()
	waMu.Lock()
	defer waMu.Unlock()

	assertion, session, err := instance.BeginLogin(currentWAUser())
	if err != nil {
		return nil, err
	}
	waLoginSession = session
	return assertion, nil
}

// WAVerifyLogin parses and verifies the assertion from the browser.
func WAVerifyLogin(r *http.Request) (any, error) {
	instance := getWA()
	waMu.Lock()
	defer waMu.Unlock()

	if waLoginSession == nil {
		return nil, fmt.Errorf("no login session found")
	}

	cred, err := instance.FinishLogin(currentWAUser(), *waLoginSession, r)
	if err != nil {
		return nil, err
	}
	waLoginSession = nil

	for i := range waCredentials {
		if waCredentialsIDEqual(waCredentials[i].Credential.ID, cred.ID) {
			waCredentials[i].Credential.Authenticator.SignCount = cred.Authenticator.SignCount
			break
		}
	}
	saveWACredentials()
	return map[string]string{"status": "ok"}, nil
}

// WAListCredentials returns a human-readable summary of stored credentials.
func WAListCredentials() []map[string]string {
	waMu.Lock()
	defer waMu.Unlock()
	list := []map[string]string{}
	for _, c := range waCredentials {
		idB64 := base64.StdEncoding.EncodeToString(c.Credential.ID)
		short := idB64
		if len(short) > 10 {
			short = short[:10] + "..."
		}
		list = append(list, map[string]string{
			"label": c.RegDate.Format("2006-01-02"),
			"id":    short,
		})
	}
	return list
}

// WAClearCredentials removes all stored credentials.
func WAClearCredentials() {
	waMu.Lock()
	defer waMu.Unlock()
	waCredentials = nil
	saveWACredentials()
}

func waCredentialsIDEqual(a, b []byte) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
