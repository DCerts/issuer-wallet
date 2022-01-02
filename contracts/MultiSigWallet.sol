// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;


struct Cert {
    uint id;
    address schoolId;
    string studentId;
    string subjectId;
    address[] issuers;
    string semester;
    string grade;
    string gradeType;
    uint batchId;
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
    }

    Certs holder;
    address[] members;
    uint threshold;

    mapping(uint => Group) groups;

    mapping(uint => Cert) certs; // certId => cert
    mapping(uint => bool) certExecuted; // certId => executed
    mapping(uint => mapping(uint => mapping(address => bool))) certConfirmed; // groupId => certId => member => confirmed
    
    mapping(uint => uint[]) batches; // batchId => [certIds]
    mapping(uint => bool) batchExecuted; // batchId => executed
    mapping(uint => mapping(uint => mapping(address => bool))) batchConfirmed; // groupId => batchId => member => confirmed

    uint certCount = 0;
    uint groupCount = 0;
    uint batchCount = 0;

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
        require(isGroupConfirmed(_groupId));
        require(isMemberOfGroup(msg.sender, _groupId));
        _;
    }

    event CertsAddressInitialized(address _holder);

    event GroupWaitingForConfirmation(
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

    event GroupAdded(
        uint groupId,
        string name,
        address[] members,
        uint threshold
    );

    event CertWaitingForConfirmation(
        address creator,
        uint certId,
        address schoolId,
        string studentId,
        string subjectId,
        string semester,
        string grade,
        string gradeType,
        uint batchId
    );

    event CertConfirmed(
        address confirmer,
        uint certId
    );

    event CertAdded(
        uint certId,
        address schoolId,
        string studentId,
        string subjectId,
        string semester,
        string grade,
        string gradeType,
        uint batchId
    );

    event BatchWaitingForConfirmation(
        address creator,
        uint batchId,
        uint[] certIds
    );

    event BatchConfirmed(
        address confirmer,
        uint batchId
    );

    event BatchAdded(
        uint batchId,
        uint[] certIds
    );

    event Deposit(address _from, uint _value);

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

    constructor(address[] memory _members, uint _threshold, address _address) {
        require(_members.length > 0);
        require(_threshold > 0);
        require(_threshold <= _members.length);
        members = _members;
        threshold = _threshold;
        holder = Certs(_address);
        emit CertsAddressInitialized(_address);
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
            confirmedBy: new address[](members.length)
        });
        group.confirmedBy[0] = msg.sender;
        groups[groupId] = group;
        emit GroupWaitingForConfirmation(msg.sender, groupId, _name, _members, _threshold);
        emit GroupConfirmed(msg.sender, groupId);
        return groupId;
    }

    function confirmGroup(uint _groupId) onlyMembers public {
        require(isGroupConfirmed(_groupId) == false);
        address[] memory groupConfirmers = groups[_groupId].confirmedBy;
        uint confirmedCount = 0;
        for (uint i = 0; i < groupConfirmers.length; i++) {
            if (groupConfirmers[i] == msg.sender) {
                return;
            }
            if (groupConfirmers[i] != address(0)) {
                confirmedCount++;
            }
        }
        groups[_groupId].confirmedBy[confirmedCount] = msg.sender;
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

    function getGroup(uint _groupId) public view returns (Group memory) {
        require(_groupId < groupCount);
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
        uint certId = certCount++;
        _cert.id = certId;
        certs[certId] = _cert;
        emit CertWaitingForConfirmation(
            msg.sender,
            certId,
            _cert.schoolId,
            _cert.studentId,
            _cert.subjectId,
            _cert.semester,
            _cert.grade,
            _cert.gradeType,
            _cert.batchId
        );
        confirmCert(_groupId, certId);
        return certId;
    }

    function submitBatch(uint _groupId, Cert[] memory _certs) onlyGroup(_groupId) public returns (uint) {
        uint batchId = batchCount++;
        batches[batchId] = new uint[](_certs.length);
        for (uint i = 0; i < _certs.length; i++) {
            uint certId = certCount++;
            _certs[i].id = certId;
            certs[certId] = _certs[i];
            batches[batchId][i] = certId;
        }
        emit BatchWaitingForConfirmation(
            msg.sender,
            batchId,
            batches[batchId]
        );
        confirmBatch(_groupId, batchId);
        return batchId;
    }

    function confirmCert(uint _groupId, uint _certId) onlyGroup(_groupId) public {
        require(certConfirmed[_groupId][_certId][msg.sender] == false);
        certConfirmed[_groupId][_certId][msg.sender] = true;
        emit CertConfirmed(msg.sender, _certId);
        executeCert(_groupId, _certId);
    }

    function confirmBatch(uint _groupId, uint _batchId) onlyGroup(_groupId) public {
        require(batchConfirmed[_groupId][_batchId][msg.sender] == false);
        batchConfirmed[_groupId][_batchId][msg.sender] = true;
        for (uint i = 0; i < batches[_batchId].length; i++) {
            uint certId = batches[_batchId][i];
            certConfirmed[_groupId][certId][msg.sender] = true;
        }
        emit BatchConfirmed(msg.sender, _batchId);
        executeBatch(_groupId, _batchId);
    }

    function executeCert(uint _groupId, uint _certId) onlyGroup(_groupId) private {
        require(certExecuted[_certId] == false);
        require(isCertConfirmed(_groupId, _certId));
        certs[_certId].issuers = getCertConfirmers(_groupId, _certId);
        holder.addCert(certs[_certId]);
        certExecuted[_certId] = true;
        emit CertAdded(
            _certId,
            certs[_certId].schoolId,
            certs[_certId].studentId,
            certs[_certId].subjectId,
            certs[_certId].semester,
            certs[_certId].grade,
            certs[_certId].gradeType,
            certs[_certId].batchId
        );
    }

    function executeBatch(uint _groupId, uint _batchId) onlyGroup(_groupId) private {
        require(batchExecuted[_batchId] == false);
        require(isBatchConfirmed(_groupId, _batchId));
        address[] memory confirmers = getBatchConfirmers(_groupId, _batchId);
        Cert[] memory batchCerts = new Cert[](batches[_batchId].length);
        for (uint i = 0; i < batches[_batchId].length; i++) {
            uint certId = batches[_batchId][i];
            certs[certId].issuers = confirmers;
            batchCerts[i] = certs[certId];
        }
        holder.addCerts(batchCerts);
        batchExecuted[_batchId] = true;
        emit BatchAdded(
            _batchId,
            batches[_batchId]
        );
    }
}