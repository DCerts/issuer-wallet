// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;


struct Cert {
    uint id;
    address schoolId;
    string regNo;
    uint batchId;
    string conferredOn;
    string dateOfBirth;
    string yearOfGraduation;
    string majorIn;
    string degreeOf;
    string degreeClassification;
    string modeOfStudy;
    string createdIn;
    string createdAt;
    address[] issuers;
}

interface Certs {
    function addCert(Cert memory _cert) external;
    function addCerts(Cert[] memory _certs) external;
}

contract MultiSigWallet {

    struct Group {
        uint id;
        string name;
        address[] members;
        uint threshold;
        address[] confirmedBy;
        address[] rejectedBy;
    }

    struct Batch {
        uint id;
        string name;
    }

    Certs holder;
    string schoolName;
    address[] members;
    uint threshold;

    mapping(uint => Group) groups;

    mapping(uint => Batch) batches; // batchId => batchName
    mapping(uint => Cert) certs; // certId => cert
    mapping(uint => bool) certExecuted; // certId => executed
    mapping(uint => mapping(uint => mapping(address => bool))) certConfirmed; // groupId => certId => member => confirmed

    mapping(uint => uint[]) batchCerts; // batchId => [certIds]
    mapping(uint => bool) batchExecuted; // batchId => executed
    mapping(uint => mapping(uint => mapping(address => bool))) batchConfirmed; // groupId => batchId => member => confirmed

    uint certCount = 0;
    uint batchCount = 0;
    uint groupCount = 0;

    function isMember(address _member) public view returns (bool) {
        for (uint i = 0; i < members.length; i++) {
            if (members[i] == _member) {
                return true;
            }
        }
        return false;
    }

    function isMemberOfGroup(address _member, uint _groupId) public view returns (bool) {
        if (groups[_groupId].members.length == 0) {
            return false;
        }
        for (uint i = 0; i < groups[_groupId].members.length; i++) {
            if (groups[_groupId].members[i] == _member) {
                return true;
            }
        }
        return false;
    }

    modifier onlyMembers {
        require(isMember(msg.sender));
        _;
    }

    modifier onlyGroup(uint _groupId) {
        require(isGroupRejected(_groupId) == false);
        require(isGroupConfirmed(_groupId));
        require(isMemberOfGroup(msg.sender, _groupId));
        _;
    }

    event WalletActivated(
        string schoolName,
        address[] members,
        uint threshold,
        address certsAddress
    );

    event GroupPending(
        address creator,
        uint groupId,
        string name,
        address[] members,
        uint threshold
    );

    event GroupConfirmed(
        address confirmer,
        uint groupId
    );

    event GroupRejected(
        address rejecter,
        uint groupId
    );

    event GroupAdded(
        uint groupId,
        string name,
        address[] members,
        uint threshold
    );

    event GroupRemoved(
        uint groupId
    );

    event CertPending(
        address creator,
        uint certId,
        string regNo,
        uint batchId
    );

    event CertConfirmed(
        address confirmer,
        uint certId,
        string regNo,
        uint batchId
    );

    event CertRejected(
        address rejecter,
        uint certId,
        string regNo,
        uint batchId
    );

    event CertAdded(
        uint certId,
        string regNo,
        uint batchId
    );

    event CertRemoved(
        uint certId
    );

    event BatchPending(
        address creator,
        uint groupId,
        uint batchId,
        string regNo,
        Cert[] certs
    );

    event BatchConfirmed(
        address confirmer,
        uint batchId,
        string regNo
    );

    event BatchRejected(
        address rejecter,
        uint batchId,
        string regNo
    );

    event BatchAdded(
        uint batchId,
        string regNo,
        uint[] certIds
    );

    event BatchRemoved(
        uint batchId
    );

    event Deposit(address from, uint value);

    fallback() external payable {
        if (msg.value > 0) {
            emit Deposit(msg.sender, msg.value);
        }
    }

    receive() external payable {
        if (msg.value > 0) {
            emit Deposit(msg.sender, msg.value);
        }
    }

    constructor(string memory _name, address[] memory _members, uint _threshold, address _address) {
        require(_members.length > 0);
        require(_threshold > 0);
        require(_threshold <= _members.length);
        schoolName = _name;
        members = _members;
        threshold = _threshold;
        holder = Certs(_address);
        emit WalletActivated(_name, _members, _threshold, _address);
    }

    function isGroupConfirmedBy(uint _groupId, address _member) public view returns (bool) {
        for (uint i = 0; i < groups[_groupId].confirmedBy.length; i++) {
            if (groups[_groupId].confirmedBy[i] == _member) {
                return true;
            }
        }
        return false;
    }

    function isGroupRejectedBy(uint _groupId, address _member) public view returns (bool) {
        for (uint i = 0; i < groups[_groupId].rejectedBy.length; i++) {
            if (groups[_groupId].rejectedBy[i] == _member) {
                return true;
            }
        }
        return false;
    }

    function isGroupConfirmed(uint _groupId) private view returns (bool) {
        uint confirmedCount = 0;
        for (uint i = 0; i < groups[_groupId].confirmedBy.length; i++) {
            if (groups[_groupId].confirmedBy[i] != address(0)) {
                confirmedCount++;
            }
        }
        return confirmedCount >= threshold;
    }

    function isGroupRejected(uint _groupId) private view returns (bool) {
        uint rejectedCount = 0;
        for (uint i = 0; i < groups[_groupId].rejectedBy.length; i++) {
            if (groups[_groupId].rejectedBy[i] != address(0)) {
                rejectedCount++;
            }
        }
        return rejectedCount >= threshold;
    }

    function addGroup(string memory _name, address[] memory _members, uint _threshold) onlyMembers public returns (uint) {
        require(_members.length > 0);
        require(_threshold > 0);
        require(_threshold <= _members.length);
        uint groupId = groupCount++;
        Group memory group = Group({
            id: groupId,
            name: _name,
            members: _members,
            threshold: _threshold,
            confirmedBy: new address[](members.length),
            rejectedBy: new address[](members.length)
        });
        group.confirmedBy[0] = msg.sender;
        groups[groupId] = group;
        emit GroupPending(msg.sender, groupId, _name, _members, _threshold);
        emit GroupConfirmed(msg.sender, groupId);
        return groupId;
    }

    function confirmGroup(uint _groupId) onlyMembers public {
        require(isGroupRejected(_groupId) == false);
        require(isGroupConfirmed(_groupId) == false);
        require(isGroupRejectedBy(_groupId, msg.sender) == false);
        address[] memory groupConfirmers = groups[_groupId].confirmedBy;
        uint confirmerCount = 0;
        for (uint i = 0; i < groupConfirmers.length; i++) {
            if (groupConfirmers[i] == msg.sender) {
                require(false);
            }
            if (groupConfirmers[i] != address(0)) {
                confirmerCount++;
            }
        }
        groups[_groupId].confirmedBy[confirmerCount] = msg.sender;
        emit GroupConfirmed(msg.sender, _groupId);
        if (isGroupConfirmed(_groupId)) {
            emit GroupAdded(
                _groupId,
                groups[_groupId].name,
                groups[_groupId].members,
                groups[_groupId].threshold
            );
        }
    }

    function rejectGroup(uint _groupId) onlyMembers public {
        require(isGroupConfirmed(_groupId) == false);
        require(isGroupRejected(_groupId) == false);
        require(isGroupConfirmedBy(_groupId, msg.sender) == false);
        address[] memory groupRejecters = groups[_groupId].rejectedBy;
        uint rejecterCount = 0;
        for (uint i = 0; i < groupRejecters.length; i++) {
            if (groupRejecters[i] == msg.sender) {
                require(false);
            }
            if (groupRejecters[i] != address(0)) {
                rejecterCount++;
            }
        }
        groups[_groupId].rejectedBy[rejecterCount] = msg.sender;
        emit GroupRejected(msg.sender, _groupId);
        if (isGroupRejected(_groupId)) {
            emit GroupRemoved(_groupId);
        }
    }

    function getGroup(uint _groupId) public view returns (Group memory) {
        return groups[_groupId];
    }

    function getCertConfirmers(uint _groupId, uint _certId) private view returns (address[] memory) {
        address[] memory confirmers;
        uint count = 0;
        for (uint i = 0; i < members.length; i++) {
            if (certConfirmed[_groupId][_certId][members[i]]) {
                confirmers[count] = members[i];
                count++;
            }
        }
        return confirmers;
    }

    function getBatchConfirmers(uint _groupId, uint _batchId) private view returns (address[] memory) {
        address[] memory confirmers;
        uint count = 0;
        for (uint i = 0; i < members.length; i++) {
            if (batchConfirmed[_groupId][_batchId][members[i]]) {
                confirmers[count] = members[i];
                count++;
            }
        }
        return confirmers;
    }

    function isCertConfirmed(uint _groupId, uint _certId) public view returns (bool) {
        address[] memory confirmers = getCertConfirmers(_groupId, _certId);
        uint count = confirmers.length;
        return count >= groups[_groupId].threshold;
    }

    function isBatchConfirmed(uint _groupId, uint _batchId) public view returns (bool) {
        address[] memory confirmers = getBatchConfirmers(_groupId, _batchId);
        uint count = confirmers.length;
        return count >= groups[_groupId].threshold;
    }

    function submitCert(uint _groupId, Cert memory _cert) onlyGroup(_groupId) public returns (uint) {
        _cert.id = certCount++;
        certs[_cert.id] = _cert;
        emit CertPending(
            msg.sender,
            _cert.id,
            _cert.regNo,
            _cert.batchId
        );
        confirmCert(_groupId, _cert.id);
        return _cert.id;
    }

    function submitBatch(uint _groupId, Batch memory _batch, Cert[] memory _certs) onlyGroup(_groupId) public returns (uint) {
        uint batchId = batchCount++;
        _batch.id = batchId;
        batches[batchId] = _batch;
        batchCerts[batchId] = new uint[](_certs.length);
        for (uint i = 0; i < _certs.length; i++) {
            _certs[i].id = certCount++;
            uint certId = _certs[i].id;
            certs[certId] = _certs[i];
            batchCerts[batchId][i] = certId;
        }
        emit BatchPending(
            msg.sender,
            _groupId,
            batchId,
            _batch.name,
            _certs
        );
        confirmBatch(_groupId, batchId);
        return batchId;
    }

    function confirmCert(uint _groupId, uint _certId) onlyGroup(_groupId) public {
        require(certConfirmed[_groupId][_certId][msg.sender] == false);
        certConfirmed[_groupId][_certId][msg.sender] = true;
        Cert memory cert = certs[_certId];
        emit CertConfirmed(msg.sender, _certId, cert.regNo, cert.batchId);
        executeCert(_groupId, _certId);
    }

    function confirmBatch(uint _groupId, uint _batchId) onlyGroup(_groupId) public {
        require(batchConfirmed[_groupId][_batchId][msg.sender] == false);
        batchConfirmed[_groupId][_batchId][msg.sender] = true;
        for (uint i = 0; i < batchCerts[_batchId].length; i++) {
            uint certId = batchCerts[_batchId][i];
            certConfirmed[_groupId][certId][msg.sender] = true;
            Cert memory cert = certs[certId];
            emit CertConfirmed(msg.sender, certId, cert.regNo, cert.batchId);
        }
        emit BatchConfirmed(msg.sender, _batchId, batches[_batchId].name);
        executeBatch(_groupId, _batchId);
    }

    function executeCert(uint _groupId, uint _certId) onlyGroup(_groupId) private {
        require(certExecuted[_certId] == false);
        require(isCertConfirmed(_groupId, _certId));
        certs[_certId].issuers = getCertConfirmers(_groupId, _certId);
        Cert memory cert = certs[_certId];
        holder.addCert(cert);
        certExecuted[_certId] = true;
        emit CertAdded(
            cert.id,
            cert.regNo,
            cert.batchId
        );
    }

    function executeBatch(uint _groupId, uint _batchId) onlyGroup(_groupId) private {
        require(batchExecuted[_batchId] == false);
        require(isBatchConfirmed(_groupId, _batchId));
        address[] memory confirmers = getBatchConfirmers(_groupId, _batchId);
        uint currentCertCount = batchCerts[_batchId].length;
        Cert[] memory currentCerts = new Cert[](currentCertCount);
        for (uint i = 0; i < currentCertCount; i++) {
            uint certId = batchCerts[_batchId][i];
            certs[certId].issuers = confirmers;
            currentCerts[i] = certs[certId];
        }
        holder.addCerts(currentCerts);
        batchExecuted[_batchId] = true;
        for (uint i = 0; i < currentCertCount; i++) {
            Cert memory cert = currentCerts[i];
            emit CertAdded(
                cert.id,
                cert.regNo,
                cert.batchId
            );
        }
        emit BatchAdded(
            _batchId,
            batches[_batchId].name,
            batchCerts[_batchId]
        );
    }
}