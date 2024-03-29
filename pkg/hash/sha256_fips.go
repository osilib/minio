// MinIO Cloud Storage, (C) 2021 MinIO, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//go:build fips

package hash

import (
	"crypto/sha256"
	"hash"
)

// newSHA256 returns a new hash.Hash computing the SHA256 checksum.
// The SHA256 implementation is FIPS 140-2 compliant when the
// boringcrypto branch of Go is used.
// Ref: https://github.com/golang/go/tree/dev.boringcrypto
func newSHA256() hash.Hash { return sha256.New() }
