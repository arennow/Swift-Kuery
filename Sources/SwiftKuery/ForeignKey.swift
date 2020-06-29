/**
 Copyright IBM Corporation 2016, 2017, 2018, 2019

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation

public enum ConstraintAction: Buildable {
    public enum Behavior: Buildable {
        case noAction
        case restrict
        case setNull
        case setDefault
        case cascade
        
        public func build(queryBuilder: QueryBuilder) -> String {
            // For the moment, we're just returning fixed strings. I'm pretty sure SQLite and MySQL use the same syntax for these anyway.
            
            switch self {
                case .noAction: return "NO ACTION"
                case .restrict: return "RESTRICT"
                case .setNull: return "SET NULL"
                case .setDefault: return "SET DEFAULT"
                case .cascade: return "CASCADE"
            }
        }
    }
    
    case onUpdate(Behavior)
    case onDelete(Behavior)
    
    public func build(queryBuilder: QueryBuilder) -> String {
        switch self {
            case .onUpdate(let b): return "ON UPDATE \(b.build(queryBuilder: queryBuilder))"
            case .onDelete(let b): return "ON DELETE \(b.build(queryBuilder: queryBuilder))"
        }
    }
}

struct ForeignKey: Buildable {
    var keyColumns: [Column]
    var refColumns: [Column]
    var keyNames: [String]
    var refNames: [String]
    var constraintActions: [ConstraintAction]

    public init?(keys: [Column], refs: [Column], _ tableName: String, actions: [ConstraintAction] = [], _ errorString: inout String) {
        if !ForeignKey.validKey(keys, refs, tableName, &errorString) {
            return nil
        }
        keyColumns = keys
        refColumns = refs
        keyNames = keyColumns.map { "\($0._table._name).\($0.name)" }
        refNames = refColumns.map { "\($0._table._name).\($0.name)" }
        constraintActions = actions
    }

    static func validKey(_ keys: [Column], _ refs: [Column],_ tableName: String, _ errorString: inout String) -> Bool {
        if keys.count == 0 || refs.count == 0 || keys.count != refs.count {
            errorString = "Invalid definition of foreign key. "
            return false
        }
        else if !columnsBelongToSameTable(columns: keys, tableName: tableName) {
            errorString = "Foreign key contains columns from another table. "
            return false
        }
        else if !columnsBelongToSameTable(columns: refs, tableName: refs[0]._table._name) {
            errorString = "Foreign key references columns from more than one table. "
            return false
        }
        return true
    }

    static func columnsBelongToSameTable(columns: [Column], tableName: String) -> Bool {
        for column in columns {
            if column.table._name != tableName {
                return false
            }
        }
        return true
    }

    static public func == (lhs: ForeignKey, rhs: ForeignKey) -> Bool {
        // Foreign keys cannot span databases and we do not currently support temporary tables therefore checking key name and ref name sets match is sufficient to establish equality
        if !(Set(lhs.keyNames) == Set(rhs.keyNames)) {
            return false
        }
        if !(Set(lhs.refNames) == Set(rhs.refNames)) {
            return false
        }
        return true
    }

    public func build(queryBuilder: QueryBuilder) -> String {
        var append = ", FOREIGN KEY ("
        append += keyColumns.map { Utils.packName($0.name, queryBuilder: queryBuilder) }.joined(separator: ", ")
        append += ") REFERENCES "
        append += Utils.packName(refColumns[0].table._name, queryBuilder: queryBuilder)
        append += "("
        append += refColumns.map { Utils.packName($0.name, queryBuilder: queryBuilder) }.joined(separator: ", ")
        append += ")"
        append += constraintActions.map { " " + $0.build(queryBuilder: queryBuilder) }.joined()
        return append
    }
}

extension ForeignKey: Hashable {

    #if swift(>=4.2)
    public func hash(into hasher: inout Hasher) {
        let baseHash = "foreignKey".hashValue
        hasher.combine(baseHash)
        for key in keyNames {
            hasher.combine(baseHash ^ key.hashValue)
        }
        for ref in refNames {
            hasher.combine(baseHash ^ ref.hashValue)
        }
    }
    #else
    public var hashValue: Int {
        var hashvalue = "foreignKey".hashValue
        for key in keyNames {
            hashvalue = hashvalue ^ key.hashValue
        }
        for ref in refNames {
            hashvalue = hashvalue ^ ref.hashValue
        }
        return hashvalue
    }
    #endif

}
