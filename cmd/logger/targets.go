/*
 * MinIO Cloud Storage, (C) 2018 MinIO, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package logger

// Target is the entity that we will receive
// a single log entry and Send it to the log target
//
//	e.g. Send the log to a http server
type Target interface {
	String() string
	Endpoint() string
	Validate() error
	Send(entry interface{}, errKind string) error
}

// Targets is the set of enabled loggers
var Targets = []Target{}

// AuditTargets is the list of enabled audit loggers
var AuditTargets = []Target{}

// AddAuditTarget adds a new audit logger target to the
// list of enabled loggers
func AddAuditTarget(t Target) error {
	if err := t.Validate(); err != nil {
		return err
	}

	AuditTargets = append(AuditTargets, t)
	return nil
}

// AddTarget adds a new logger target to the
// list of enabled loggers
func AddTarget(t Target) error {
	if err := t.Validate(); err != nil {
		return err
	}
	Targets = append(Targets, t)
	return nil
}
